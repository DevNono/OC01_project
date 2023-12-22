#include <ArduinoBLE.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <time.h>
#include <UUID.h>

#include <WebSocketsClient.h>
#include <SocketIOclient.h>

// Common variables
#define BT_NAME "OC01-T0DD" // We could use the serial number here
#define NTP_SERVER "time.nist.gov"
#define NTP_OFFSET 3600 * 1
#define NTP_DAYLIGHT 3600 * 0
// Whether or not the alarm should be silent
#define SILENT_MODE false

// Hardware pins
#define PINCODE 32
#define LED1 25
#define LED2 26
#define MAGNETIC 33
#define BUZZER 2

// delays and more
#define DEBOUNCE_DELAY 500
#define OPEN_DELAY 10000

// open/close door variables
bool isAllowedToOpen = false;
unsigned long maxTimeToOpen = 0;
unsigned long lastTimedAlarmEvent = 0;

// Pincode variables
char lastKey;
unsigned long lastDebounceTime = 0;
String code = "1234";
String attempt = "";

// States variables
String SERIAL_NUMBER;
bool isWifiConnected = false;
bool isSetup = false;
bool isSocketConnected = false;
bool isSocketLoggedIn = false;
bool isActivated = false;
bool isOpened = false;
bool serverTimeEnabled = true;
String socketError = "";

// Library variables
BLEService* customService;
BLEStringCharacteristic* customCharacteristic;
Preferences preferences;
SocketIOclient socketIO;

// ------------------------------
//            UTILS
// ------------------------------

// Function to generate random string used for secret
char *getRandomStr(int len)
{
  char *output = new char[len + 1]; // Allocate space for the null terminator
  char *eligible_chars = "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890+#%=()[]";
  for (int i = 0; i < len; i++)
  {
    uint8_t random_index = random(0, strlen(eligible_chars));
    output[i] = eligible_chars[random_index];
  }
  output[len] = '\0'; // Null terminate the string
  return output;
}

// Function to get current time
tm getTime()
{
  struct tm timeinfo;
  if (serverTimeEnabled && isWifiConnected && !getLocalTime(&timeinfo))
  {
    Serial.println("Failed to obtain time");
    serverTimeEnabled = false;
  }

  return timeinfo;
}

// Function to get current timestamp
time_t getTimestamp()
{
  struct tm timeinfo;
  if (serverTimeEnabled && isWifiConnected && !getLocalTime(&timeinfo))
  {
    Serial.println("Failed to obtain time");
    serverTimeEnabled = false;
  }

  return mktime(&timeinfo);
}

// Function to log messages
void logging(const char *title, const char *message)
{
  String time;
  if (serverTimeEnabled && isWifiConnected) {
    tm timeinfo = getTime();
    time = "[" + String(timeinfo.tm_hour) + ":" + String(timeinfo.tm_min) + ":" + String(timeinfo.tm_sec) + "]";
  } else {
    time = "[00:00:00]";
  }

  Serial.println(time + " [" + title + "] " + message);
}

// Function to reset device
void factoryReset() {
  preferences.begin("device", false);
  preferences.remove("serial");
  preferences.remove("serveraddress");
  preferences.remove("secret");
  preferences.remove("setup");
  preferences.remove("pincode");
  preferences.end();

  preferences.begin("wifi", false);
  preferences.remove("ssid");
  preferences.remove("password");
  preferences.end();

  delay(2000);

  // restart ESP32
  ESP.restart();
}

// ------------------------------
//        WiFi and Socket
// ------------------------------

// Function to handle WiFi events
void WiFiEvent(WiFiEvent_t event)
{
  switch (event)
  {
  case SYSTEM_EVENT_STA_DISCONNECTED:
    // We have lost connection to the WiFi network
    logging("WiFi", "Disconnected from WiFi");

    isWifiConnected = false;
    isSocketConnected = false;
    isSocketLoggedIn = false;
    break;
  default:
    break;
  }
}

// Function to setup wifi connection
bool setupWifiConnection(const char *ssid, const char *password)
{
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  logging("WiFi", ("Connecting to SSID \"" + String(ssid) + "\"").c_str());

  unsigned long startAttemptTime = millis();

  while (WiFi.status() != WL_CONNECTED)
  {
    Serial.print(".");

    if (WiFi.status() == WL_CONNECT_FAILED || millis() - startAttemptTime > 20000)
    {
      return false;
    }
    delay(100);
  }

  Serial.println("");
  logging("WiFi", "Connected to the WiFi network");
  logging("WiFi", ("Local ESP32 IP: " + WiFi.localIP().toString()).c_str());

  configTime(NTP_OFFSET, NTP_DAYLIGHT, NTP_SERVER);

  WiFi.onEvent(WiFiEvent);

  return true;
}

// Function to login or register to the websocket server
bool loginOrRegister(bool isLogin = false)
{
  preferences.begin("device", false);
  String secret = preferences.getString("secret");
  preferences.end();

  DynamicJsonDocument doc(1024);
  doc["serial"] = SERIAL_NUMBER;
  doc["secret"] = secret;
  doc["type"] = "device";

  if (isSetup || isLogin)
  {
    // send event login
    sendEvent("login", doc.as<JsonObject>());
  }
  else
  {
    // send event register
    sendEvent("register", doc.as<JsonObject>());
  }

  unsigned long startAttemptTime = millis();

  while (!isSocketLoggedIn && !isLogin)
  {
    socketIO.loop();

    Serial.print(".");

    if (socketError != "")
    {
      logging("Socket", ("Error: " + socketError).c_str());
      return false;
    }

    if (millis() - startAttemptTime > 40000)
    {
      return false;
    }

    delay(100);
  }

  return true;
}

// Function to setup websocket connection
bool setupWebsocketConnection(const char *address)
{
  logging("Socket", ("Connecting to Socket.IO using address: " + String(address)).c_str());

  // server address, port and URL
  // if address contains 192.168 it's a local address so we don't use SSL
  if (String(address).indexOf("192.168") != -1) {
    socketIO.begin(address, 4800, "/socket.io/?EIO=4");
  } else {
    socketIO.beginSSL(address, 443, "/socket.io/?EIO=4");
  }

  // event handler
  socketIO.onEvent(socketIOEvent);

  // try ever 5000ms again if connection has failed
  socketIO.setReconnectInterval(5000);

  logging("Socket", "Waiting for Socket.IO connection");

  unsigned long startAttemptTime = millis();

  while (!socketIO.isConnected())
  {
    socketIO.loop();
    Serial.print(".");

    if (millis() - startAttemptTime > 60000)
    {
      return false;
    }

    delay(100);
  }

  return true;
}

// Function to send events to the websocket server
void sendEvent(const char *event, JsonObject data)
{
  DynamicJsonDocument doc(1024);
  JsonArray array = doc.to<JsonArray>();

  array.add(event);
  array.add(data);

  String output;
  serializeJson(doc, output);

  socketIO.sendEVENT(output);
}

// Function to handle websocket events
void socketIOEvent(socketIOmessageType_t type, uint8_t *payload, size_t length)
{
  switch (type)
  {
  case sIOtype_DISCONNECT:
    // We are disconnected
    Serial.println("");
    logging("Socket", "Disconnected");

    isSocketConnected = false;
    isSocketLoggedIn = false;

    break;
  case sIOtype_CONNECT:
    // We are connected
    Serial.println("");
    logging("Socket", ("Connected to url: " + String((char *)payload)).c_str());

    isSocketConnected = true;

    // join default namespace (no auto join in Socket.IO V3)
    socketIO.send(sIOtype_CONNECT, "/");
    break;
  case sIOtype_EVENT:
  {
    // Handle events
    char *sptr = NULL;
    int id = strtol((char *)payload, &sptr, 10);

    if (id)
    {
      payload = (uint8_t *)sptr;
    }
    DynamicJsonDocument doc(1024);
    DeserializationError error = deserializeJson(doc, payload, length);
    if (error)
    {
      Serial.println("");
      logging("Socket", ("DeserializationError: " + String(error.c_str())).c_str());
      return;
    }

    String eventName = doc[0];
    Serial.println("");
    logging("Socket", ("Event: " + eventName).c_str());
    
    if (eventName == "callback-login")
    {
      if (doc[1]["status"] == false)
      {
        // Logging in was successful so we can get the activated state
        isActivated = doc[1]["data"]["activated"].as<bool>();
        logging("Socket", ("Activated: " + String(isActivated)).c_str());
        isSocketLoggedIn = true;
      }
      else
      {
        socketError = doc[1]["data"]["message"].as<String>();
      }
    }

    if (eventName == "callback-register")
    {
      if (doc[1]["status"] == false)
      {
        // Send Login
        loginOrRegister(true);
      }
      else
      {
        socketError = doc[1]["data"]["message"].as<String>();
      }
    }

    if (eventName == "callback-event")
    {
      // Event was sent callback
      logging("Socket", doc[1]["data"]["message"]);
    }

    if (eventName == "unpair")
    {
      // Unpairing device
      logging("Socket", "Unpairing device");
      
      isSocketLoggedIn = false;
      isSocketConnected = false;
      isWifiConnected = false;
      isSetup = false;

      DynamicJsonDocument doc(1024);
      doc["callback"] = true;

      sendEvent("unpair", doc.as<JsonObject>());

      factoryReset();
    }

    if (eventName == "changepin")
    {
      // Changing pincode
      code = doc[1]["data"]["pin"].as<String>();

      logging("Socket", ("Changing pincode to " + code).c_str());

      preferences.begin("device", false);
      preferences.putString("pincode", String(code));
      preferences.end();

      DynamicJsonDocument doc(1024);
      doc["callback"] = true;

      sendEvent("changepin", doc.as<JsonObject>());
    }

    if (eventName == "statuschanged")
    {
      // Status changed so we update the activated state
      isActivated = doc[1]["activated"].as<bool>();
      logging("Socket", ("Activated: " + String(isActivated)).c_str());

      DynamicJsonDocument doc(1024);
      doc["callback"] = true;

      sendEvent("statuschanged", doc.as<JsonObject>());
    }
  }
  break;
  case sIOtype_ERROR:
    // An error occurred
    Serial.println("");
    logging("Socket", "ERROR received");
    break;
  }
}

// ------------------------------
//            BLE
// ------------------------------

// Function to parse data received from BLE
void parseData(std::string data)
{
  DynamicJsonDocument jsonDocument(1024);
  DeserializationError error = deserializeJson(jsonDocument, data);

  if (!error)
  {
    if (jsonDocument.containsKey("event") && jsonDocument.containsKey("data"))
    {
      String event = jsonDocument["event"];
      JsonObject data = jsonDocument["data"];

      logging("BLE", ("Event: " + event).c_str());

      if (event == "wifi")
      {
        const char *ssid = data["ssid"];
        const char *password = data["password"];

        // Store the ssid and password in the preferences
        preferences.begin("wifi", false);
        preferences.putString("ssid", String(ssid));
        preferences.putString("password", String(password));
        preferences.end();

        isWifiConnected = setupWifiConnection(ssid, password);

        // Prepare a response JSON document
        DynamicJsonDocument doc(1024);
        doc["event"] = "cb-wifi";
        JsonObject data = doc.createNestedObject("data");
        data["status"] = isWifiConnected;

        String output;
        serializeJson(doc, output);

        // Send the response
        customCharacteristic->writeValue(output.c_str());
      }

      if (event == "server")
      {
        const char *address = data["address"];

        // Store the server address in the preferences
        preferences.begin("device", false);
        preferences.putString("serveraddress", String(address));
        preferences.end();

        isSocketConnected = setupWebsocketConnection(address);

        // Prepare a response JSON document
        DynamicJsonDocument doc(1024);
        doc["event"] = "cb-server";
        JsonObject data = doc.createNestedObject("data");

        if (isSocketConnected)
        {
          data["serial"] = SERIAL_NUMBER;

          const char *secret = getRandomStr(64);

          // Store the secret in the preferences
          preferences.begin("device", false);
          preferences.putString("secret", String(secret));
          preferences.end();

          loginOrRegister();

          data["secret"] = secret;
        }

        data["status"] = isSocketLoggedIn;

        // If there is an error, we send it back
        if (socketError != "")
        {
          data["message"] = socketError;

          socketError = "";
        }

        String output;
        serializeJson(doc, output);

        // Send the response
        customCharacteristic->writeValue(output.c_str());
      }

      if (event == "setup")
      {
        // Setup is finished
        isSetup = true;
        preferences.begin("device", false);
        preferences.putBool("setup", true);
        preferences.end();

        // Prepare a response JSON document
        DynamicJsonDocument doc(1024);
        doc["event"] = "cb-setup";
        JsonObject data = doc.createNestedObject("data");
        data["status"] = true;

        String output;
        serializeJson(doc, output);

        // Send the response
        customCharacteristic->writeValue(output.c_str());

        // We wait 2 seconds before restarting the BLE to avoid errors
        delay(2000);

        // Disconnect the BLE if it's connected
        if (BLE.connected())
        {
          BLE.disconnect();
        }
      }
    }
    else
    {
      logging("BLE", "Received a message, but it does not contain 'event' and 'data' fields");
    }
  }
  else
  {
    logging("BLE", ("Failed to parse JSON: " + String(error.c_str())).c_str());
  }
}

// ------------------------------
//            MAIN
// ------------------------------

// Setup function
void setup()
{
  Serial.begin(115200);
  while (!Serial)
    ;

  pinMode(PINCODE, INPUT);
  pinMode(LED1, OUTPUT);
  pinMode(LED2, OUTPUT);
  pinMode(MAGNETIC, INPUT);
  pinMode(BUZZER, OUTPUT);

  preferences.begin("device", false);
  isSetup = preferences.getBool("setup", false);
  preferences.end();

  if (isSetup){
    logging("Setup", "Already setup");

    // Load code from preferences
    preferences.begin("device", false);
    String pincodetemp = preferences.getString("pincode");
    SERIAL_NUMBER = preferences.getString("serial");
    preferences.end();

    if(pincodetemp != "" && pincodetemp.length() == 4) {
      code = pincodetemp.c_str();
    }
  } else {
    logging("Setup", "Not setup yet");

    // Generate serial number
    uint32_t seed1 = random(999999999);
    uint32_t seed2 = random(999999999);

    UUID uuid;
    uuid.seed(seed1, seed2);
    uuid.setVariant4Mode();
    uuid.generate();
    SERIAL_NUMBER = uuid.toCharArray();

    preferences.begin("device", false);
    preferences.putString("serial", SERIAL_NUMBER);
    preferences.end();

    logging("Setup", ("Serial: " + SERIAL_NUMBER).c_str());
  }

  // Initialize customService and customCharacteristic for BLE
  customService = new BLEService(SERIAL_NUMBER.c_str());
  customCharacteristic = new BLEStringCharacteristic(SERIAL_NUMBER.c_str(), BLERead | BLEWrite, 2048);
}

// Loop function
void loop()
{
  while (!isWifiConnected || !isSetup || !isSocketConnected || !isSocketLoggedIn)
  {
    if (!isSetup)
    {
      // Initialize the BLE device
      if (!BLE.begin())
      {
        logging("BLE", "Starting BLE failed!");
        while (1)
          ;
      }

      // Set BLE device name
      BLE.setLocalName(BT_NAME);

      // Add the characteristic to the service
      customService->addCharacteristic(*customCharacteristic);

      // Add the service
      BLE.addService(*customService);

      // Advertise the service
      BLE.advertise();

      logging("BLE", "Waiting for a client to connect...");

      // while no client is connected and we are not setup
      while (!BLE.connected() || !isSetup)
      {
        // listen for BLE peripherals to connect:
        BLEDevice central = BLE.central();

        // if a central is connected to peripheral:
        if (central)
        {
          logging("BLE", ("Connected to central: " + central.address()).c_str());
          // while the central is still connected to peripheral:
          while (central.connected())
          {
            if (customCharacteristic->written())
            {
              // read the value sent from the central
              String data = customCharacteristic->value();
              if (data.length() > 0)
              {
                parseData(data.c_str());
              }
            }
          }
          logging("BLE", ("Disconnected from central:" + central.address()).c_str());

          if (!isSetup)
          {
            // Setup did not finish, so we disconnect and restart
            WiFi.disconnect(true);

            isWifiConnected = false;
            isSocketConnected = false;
            isSocketLoggedIn = false;
          }

          if(isSocketLoggedIn) {
            Serial.println("");
            logging("Socket", "Logged in");
          }

          // stop while loop
          break;
        }
      }
      return;
    }
    else
    {
      if (!isWifiConnected)
      {
        // Start WiFi connection

        // read wifi credentials from preferences
        preferences.begin("wifi", false);
        String ssid = preferences.getString("ssid");
        String password = preferences.getString("password");
        preferences.end();

        isWifiConnected = setupWifiConnection(ssid.c_str(), password.c_str());
        return;
      }
      else
      {

        if (!isSocketConnected)
        {
          // Start Socket connection

          // read server address from preferences
          preferences.begin("device", false);
          String address = preferences.getString("serveraddress");
          preferences.end();

          isSocketConnected = setupWebsocketConnection(address.c_str());
          return;
        }
        else
        {
          if (!isSocketLoggedIn)
          {
            // Start Socket login
            if (socketError != "")
            {
              logging("Socket", ("Error: " + socketError).c_str());
              delay(60000);
              return;
            }
            isSocketLoggedIn = loginOrRegister();
            if (isSocketLoggedIn)
            {
              Serial.println("");
              logging("Socket", "Logged in");
            }
            return;
          }
        }
      }
    }
  }

  socketIO.loop();

  // Normal code
  int keypadValue = analogRead(PINCODE);

  char key = ' '; // variable to store the current key pressed

  // Determine the key based on analog values
  if (keypadValue > 4070)
  {
    key = '1';
  }
  else if (keypadValue > 3720)
  {
    key = '2';
  }
  else if (keypadValue > 3400)
  {
    key = '3';
  }
  else if (keypadValue > 3160)
  {
    // If pressed for 3 seconds, reset device
    delay(3000);
    if(analogRead(PINCODE) > 3160 && analogRead(PINCODE) < 3400) {
      factoryReset(); 
    }
  } 
  else if (keypadValue > 2710)
  {
    key = '4';
  }
  else if (keypadValue > 2530)
  {
    key = '5';
  }
  else if (keypadValue > 2370)
  {
    key = '6';
  }
  else if (keypadValue > 2240)
  {
    Serial.println("Key BB pressed");
  }
  else if (keypadValue > 1980)
  {
    key = '7';
  }
  else if (keypadValue > 1890)
  {
    key = '8';
  }
  else if (keypadValue > 1800)
  {
    key = '9';
  }
  else if (keypadValue > 1720)
  {
    Serial.println("Key CC pressed");
  }
  else if (keypadValue > 1550)
  {
    Serial.println("Key LL pressed");
  }
  else if (keypadValue > 1200)
  {
    key = '0';
  }
  else if (keypadValue > 980)
  {
    Serial.println("Key RR pressed");
  }
  else if (keypadValue > 810)
  {
    Serial.println("Key VV pressed");
  }

  if ((millis() - lastDebounceTime) > DEBOUNCE_DELAY && key != ' ')
  {
    // If the key state has changed for more than the debounce delay
    lastKey = key;

    // Print the key pressed
    logging("Hardware", ("Key Pressed: " + String(key)).c_str());

    attempt += String(key);
    logging("Hardware", ("Attempt: " + String(attempt)).c_str());

    if (attempt.length() == 4)
    {
      if (attempt == code)
      {
        // Code is correct
        logging("Hardware", "Code OK!");

        isAllowedToOpen = true;
        maxTimeToOpen = millis() + OPEN_DELAY;

        DynamicJsonDocument doc(1024);
        doc["name"] = "Code correct entré";
        doc["type"] = "unlocked";
        doc["date"] = getTimestamp();

        // Send event to server
        sendEvent("event", doc.as<JsonObject>());

        if (!SILENT_MODE) {
          // Play success sound
          tone(BUZZER, 2000);
          delay(100);
          noTone(BUZZER);
        }
      }
      else
      {
        // Code is incorrect
        logging("Hardware", "Code incorrect!");

        DynamicJsonDocument doc(1024);
        doc["name"] = "Code incorrect";
        doc["type"] = "unlocked-failed";
        doc["date"] = getTimestamp();

        sendEvent("event", doc.as<JsonObject>());

        if (!SILENT_MODE) {
          // Play error sound
          tone(BUZZER, 1200);
          delay(100);
          noTone(BUZZER);
        }
      }
      attempt = "";
    }
    lastDebounceTime = millis();
  }

  digitalWrite(LED1, LOW);

  if (analogRead(MAGNETIC) > 1000)
  {
    // Door is open
    if (!isActivated || isAllowedToOpen || maxTimeToOpen >= millis())
    {
      // Everything is normal, we don't turn on the alarm
      digitalWrite(LED1, HIGH);
      digitalWrite(LED2, LOW);
      if (!isOpened)
      {
        logging("Security", "Door is open");
        isOpened = true;
      }
    }
    else
    {
      // Alarm is triggered
      digitalWrite(LED1, LOW);
      digitalWrite(LED2, HIGH);

      if (!isOpened)
      {
        logging("Security", "Door is open but alarm is triggered");

        if (lastTimedAlarmEvent < millis() - 60000)
        {
          // Send event to server
          DynamicJsonDocument doc(1024);
          doc["name"] = "Alarme déclenchée";
          doc["type"] = "alarm";
          doc["date"] = getTimestamp();

          sendEvent("event", doc.as<JsonObject>());

          lastTimedAlarmEvent = millis();
        }
        
        if (!SILENT_MODE) {
          tone(BUZZER, 900);
          delay(100);
          noTone(BUZZER);
        }

        isOpened = true;
      }
    }
  }
  else
  {
    // Door is closed
    digitalWrite(LED1, LOW);
    digitalWrite(LED2, LOW);
    if (maxTimeToOpen < millis())
    {
      isAllowedToOpen = false;
    }

    isOpened = false;
  }
  delay(50);
}
