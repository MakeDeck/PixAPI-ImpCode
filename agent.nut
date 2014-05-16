/*
Copyright (C) 2013 electric imp, inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, 
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial 
portions of the Software.
d
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE 
AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/* 
 * Vanessa Reference Design Agent Firmware
 * Tom Byrne
 * tom@electricimp.com
 * 11/21/2013
 */

server.log("Agent Running at "+http.agenturl());

/* The device spends most of its time asleep when on battery power, 
 * So the agent keeps track of parameters like the current image and display size.
 */
const WIDTH = 264;
const HEIGHT = 176;

//const WIDTH = 10;
//const HEIGHT = 10;

PIXELS <- HEIGHT * WIDTH;
BYTES_PER_SCREEN <- PIXELS / 4;

imgData <- {};
// resize image blobs to display dimensions
imgData.curImg <- blob(BYTES_PER_SCREEN);
imgData.curImgInv <- blob(BYTES_PER_SCREEN);
imgData.nxtImg <- blob(BYTES_PER_SCREEN);
imgData.nxtImgInv <- blob(BYTES_PER_SCREEN);

function clear_blobs(imgBlob) {
  // fill the current image blobs with dummy data
  for (local i = 0; i < BYTES_PER_SCREEN; i++) {
      imgBlob.curImg.writen(0xAA,'b');
  	  imgBlob.curImgInv.writen(0xFF,'b');
  }
}


clear_blobs(imgData);
imgData.nxtImg = imgData.curImg;
imgData.nxtImgInv = imgData.curImgInv;


const ui_html = @"<!DOCTYPE html>
<html lang=""en"">
    <head>
        <meta charset=""utf-8"">
        <meta name=""viewport"" content=""width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0"">
        <meta name=""apple-mobile-web-app-capable"" content=""yes"">
            
        <script src=""https://code.jquery.com/jquery-1.9.1.min.js""></script>
        <script src=""https://code.jquery.com/jquery-migrate-1.2.1.min.js""></script>
        <script src=""https://d2c5utp5fpfikz.cloudfront.net/2_3_1/js/bootstrap.min.js""></script>
        
        <link href=""//d2c5utp5fpfikz.cloudfront.net/2_3_1/css/bootstrap.min.css"" rel=""stylesheet"">
        <link href=""//d2c5utp5fpfikz.cloudfront.net/2_3_1/css/bootstrap-responsive.min.css"" rel=""stylesheet"">

        <title>PixAPI demo</title>
    </head>
    <body>
        <script type=""text/javascript"">
            function sendToImp(value){
                $.ajax({
                  type:""POST"",
                  url: document.URL,
                  data : JSON.stringify({text : value}),
                  contentType: ""application/json; charset=utf-8"",
                  dataType: ""json"",
                  success: function(data){alert(data);},
                  failure: function(errMsg) {
                      alert(errMsg);
                  }
                })
            }
            function send(){
                sendToImp(document.getElementById('newText').value);
            }
        </script>
        <div class='container'>
            <div class=''>
                
            </div>
            <div class='well' style='max-width: 320px; margin: 0 auto 10px; height:280px; font-size:22px;'>
            <h1 class='text-center'>PixAPI Demo</h1>
            <h3 class='text-center'>Enter Text to show</hr3>
            <input id='newText' type='text' name='newText' style='width:94%;'>
            <button style='width:100%; height:30%; margin-bottom:10px; margin-top:10px;' class='btn btn-primary btn-large btn-block' onclick='send()'><h1>Send Text</h1></button>
            </div>
        </div>
    </body>
</html>";

/*
 * Input: WIF image data (blob)
 *
 * Return: image data (table)
 *         	.height: height in pixels
 * 			.width:  width in pixels
 * 			.data:   image data (blob)
 */
function unpackWIF(packedData) {
	packedData.seek(0,'b');

	// length of actual data is the length of the blob minus the first four bytes (dimensions)
	local datalen = packedData.len() - 4;
	local retVal = {height = null, width = null, normal = blob(datalen*2), inverted = blob(datalen*2)};
	retVal.height = packedData.readn('w');
	retVal.width = packedData.readn('w');
	server.log("Unpacking WIF Image, Height = "+retVal.height+" px, Width = "+retVal.width+" px");

	/*
	 * Unpack WIF for RePaper Display
	 * each row is (width / 4) bytes (2 bits per pixel)
	 * first (width / 8) bytes are even pixels
	 * second (width / 8) bytes are odd pixels
	 * unpacked index must be incremented by (width / 8) every (width / 8) bytes to avoid overwriting the odd pixels.
	 *
	 * Display is drawn from top-right to bottom-left
	 *
	 * black pixel is 0b11
	 * white pixel is 0b10
	 * "don't care" is 0b00 or 0b01
	 * WIF does not support don't-care bits
	 *
	 */

	for (local row = 0; row < retVal.height; row++) {
		//for (local col = 0; col < (retVal.width / 8); col++) {
		for (local col = (retVal.width / 8) - 1; col >= 0; col--) {
			local packedByte = packedData.readn('b');
			local unpackedWordEven = 0x00;
			local unpackedWordOdd  = 0x00;
			local unpackedWordEvenInv = 0x00;
			local unpackedWordOddInv  = 0x00;

			for (local bit = 0; bit < 8; bit++) {
				// the display expects the data for each line to be interlaced; all even pixels, then all odd pixels
				if (!(bit % 2)) {
					// even pixels become odd pixels because the screen is drawn right to left
					if (packedByte & (0x01 << bit)) {
						unpackedWordOdd = unpackedWordOdd | (0x03 << (6-bit));
						unpackedWordOddInv = unpackedWordOddInv | (0x02 << (6-bit));
					} else {
						unpackedWordOdd = unpackedWordOdd | (0x02 << (6-bit));
						unpackedWordOddInv = unpackedWordOddInv | (0x03 << (6-bit));
					}
				} else {
					// odd pixel becomes even pixel
					if (packedByte & (0x01 << bit)) {
						unpackedWordEven = unpackedWordEven | (0x03 << bit - 1);
						unpackedWordEvenInv = unpackedWordEvenInv | (0x02 << bit - 1);
					} else {
						unpackedWordEven = unpackedWordEven | (0x02 << bit - 1);
						unpackedWordEvenInv = unpackedWordEvenInv | (0x03 << bit - 1);
					}
				}
			}

			retVal.normal[(row * (retVal.width/4))+col] = unpackedWordEven;
			retVal.inverted[(row * (retVal.width/4))+col] = unpackedWordEvenInv;
			retVal.normal[(row * (retVal.width/4))+(retVal.width/4) - col - 1] = unpackedWordOdd;
			retVal.inverted[(row * (retVal.width/4))+(retVal.width/4) - col - 1] = unpackedWordOddInv;

		} // end of col
	} // end of row

	server.log("Done Unpacking WIF File.");

	return retVal;
}

/* Determine seconds until the next occurance of a time string
 * This example assumes California time :)
 * 
 * Input: Time string in 24-hour time, e.g. "20:18"
 * 
 * Return: integer number of seconds until the next occurance of this time
 *
 */
function secondsTill(targetTime) {
    local data = split(targetTime,":");
    local target = { hour = data[0].tointeger(), min = data[1].tointeger() };
    local now = date(time() - (3600 * 8));
    
    if ((target.hour < now.hour) || (target.hour == now.hour && target.min < now.min)) {
        target.hour += 24;
    }
    
    local secondsTill = 0;
    secondsTill += (target.hour - now.hour) * 3600;
    secondsTill += (target.min - now.min) * 60;
    return secondsTill;
}

/* DEVICE EVENT HANDLERS ----------------------------------------------------*/

// Tell the device how big the screen is and what it has on it when it wakes up and asks.
device.on("params_req",function(data) {
    local dispParams = {};
    dispParams.height <- HEIGHT;
    dispParams.width <- WIDTH;
	device.send("params_res", dispParams);
});

device.on("readyForNewImgInv", function(data) {
    server.log("readyForNewImgInv");
    device.send("newImgInv", imgData.nxtImgInv);
});

device.on("readyForNewImgNorm", function(data) {
    server.log("readyForNewImgNorm");
    device.send("newImgNorm", imgData.nxtImg);
    
    // now move the "next image" data to "current image" in the image data table.
    imgData.curImg = imgData.nxtImg;
    imgData.curImgInv = imgData.nxtImgInv;
    
    // This completes the "new-image" process, and the display will be stopped.
});

/* Sean's temp code ---------------------------------------------------------*/

function BlobToHexString(data) {
  server.log("Blob to Hex String");
  local str = "0x";
  foreach (b in data) {
    server.log("Data" + format("%d", b));
    // str += format("%02X", b);
    str += format("%d", b);
  }
  return str;
}

/*Start PIX API CODE */

class PixApiStatus {
  statuscode = 0;
  data = "";
  constructor(new_data, new_statuscode) {
    data = new_data;
    statuscode = new_statuscode;
  }
}

class PixApiImageRequest {
  // Properties
  m_height = 0;
  m_width = 0;
  m_format = "";
  m_text_items = [];
  m_version = "";
  m_encoding = "";
  m_url = "";
  
  /**
   * @brief constructor
   * @param height - Height in pixels of the image
   * @param width - Width in pixels of the image
   * @param format = A string for the format of the image
   * Only supported format is currently 'wif'
   * @param version - string to set version to
   * @param url - URL for request
   * @param encoding for the request, should be UTF-8
   */
  constructor(height, width, format, version, url, encoding) {
    m_height = height;
    m_width = width;
    m_format = format;
    m_text_items = [];
    m_image_items = [];
    m_version = version;
    m_encoding = encoding;
    m_url = url;
  }
  
  /**
   * @brief Used to add a new text line to the image
   * @param new_text The text to render
   * @param new_x is the x position of the top left of the text
   * @param new_y is the y position of the top left of the text
   * @return a handle for the text to use to modify later (currently unused)
   */
  function addtext(new_text, new_x, new_y) {
    m_text_items.append({text=new_text, x=new_x, y=new_y});
    return m_text_items.len() - 1;
  }
  
  /**
   * @brief Used to add a new text line with a specific font and font size
   * Only .ttf(TrueType fonts) accept the font size requirement
   * @param new_text - The text line you want to render
   * @param new_x is the x position of the top left of the text
   * @param new_y is the y position of the top left of the text
   * @param new_font is a string that names the supported font including file
   * extension ex Dosis-Regular.ttf
   * @param new_font_size is a number for font size in points
   */
  function addtextwithfont(new_text, new_x, new_y, new_font, new_font_size) {
    m_text_items.append({text=new_text,
                       x=new_x,
                       y=new_y,
                       font=new_font,
                       font_size=new_font_size});
    return m_text_items.len() - 1;
  }
  
  /**
   * @brief Used to add a new image
   * @param url to the image
   * @param new_x is the x position of the top left of the image
   * @param new_y is the y position of the top left of the image
   * @return a handle for the image_item to use to modify later (currently unused)
   */
  function addimage(new_url, new_x, new_y) {
    m_text_items.append({url=new_url, x=new_x, y=new_y});
    return m_image_items.len() - 1;
  }
  
  /**
   * 
   * @return should return a blob but currently on returns a string
   */
  function render() {
    local json_object = {};
    json_object.rawset("version", m_version);
    json_object.rawset("encoding", m_encoding);
    json_object.rawset("height", m_height);
    json_object.rawset("width", m_width);
    json_object.rawset("format", m_format);
    json_object.rawset("text", m_text_items);
    json_object.rawset("image", m_image_items);
    return send_request(json_object);
  }
  
  function send_request(json_object) {
    local json_str = http.jsonencode(json_object)
    server.log("json_str: " + json_str)
    local request = http.post(m_url, {"content-type":"application/json"}, json_str)
    local http_response = request.sendsync()
    local response = {};
    if (http_response.statuscode == 200) {
      server.log("PixApi - Response Status : " + http_response.statuscode);
      return PixApiStatus(http.base64decode(http_response.body),
                          http_response.statuscode);
    } else {
      // How do we deal with errors? Return a table?
      server.log("PixApi - Response Status : " + http_response.statuscode);
      server.log("Error: " + http_response.body);
      return PixApiStatus("", http_response.statuscode);
    }
  }
}

/**
 * @brief PixApi class, is used to construct a request for the
 * pixapi
 */
class PixApi {
  // Properties
  m_height = 0;
  m_width = 0;
  PIX_API_VERSION = "1.0.0";
  PIX_API_ENCODING = "UTF-8";
  PIX_API_URL = "http://imp-pix-api.appspot.com/image";
  
  /**
   * @brief constructor
   * @param h - Height in pixels of the image
   * @param w - Width in pixels of the image
   * @param f = A string for the format of the image
   * Only supported format is currently 'wif'
   */
  constructor(height, width) {
    m_height = height;
    m_width = width;
  }
  
  function newRequest(format) {
    return PixApiImageRequest(m_height,
                              m_width,
                              format,
                              PIX_API_VERSION,
                              PIX_API_URL, PIX_API_ENCODING);
  }
}

pixapi <- PixApi(WIDTH, HEIGHT);

/*End PIX API CODE */


function testRequestImage() {
  // We want to build a json request
  local imageReq = pixapi.newRequest("wif");
  imageReq.addtext("Here is some text", 1, 1);
  imageReq.addtextwithfont("BIG TEXT!!!!!", 10, 10, "Dosis-Regular.ttf", 32);
  imageReq.addtext("TEXT!!!!!!!!!!!!!", 1, 100);
  local response = imageReq.render();
  if (response.statuscode == 200) {
    // unpack the WIF image data
  	local newImgData = unpackWIF(response.data);
  	imgData.nxtImg = newImgData.normal;
  	imgData.nxtImgInv = newImgData.inverted;

  	// send the inverted version of the image currently on the screen to start the display update process
    server.log("Sending new data to device, len: "+imgData.curImgInv.len());
    device.send("newImgStart", imgData.curImgInv);
  }
}

/* HTTP EVENT HANDLERS ------------------------------------------------------*/
function webUIHandler(request, response) {
    if (request.method == "POST") {
      local data = http.jsondecode(request.body);
      server.log("Got: " + data["text"]);
      // Go ahead and send a reposne that it was ok
      response.send(200, "OK");
      // We want to build a json request
      local imageReq = pixapi.newRequest("wif");
      imageReq.addtext(data["text"], 1, 50);
      local response = imageReq.render();
      if (response.statuscode == 200) {
        // unpack the WIF image data
      	local newImgData = unpackWIF(response.data);
      	imgData.nxtImg = newImgData.normal;
      	imgData.nxtImgInv = newImgData.inverted;
      
      	// send the inverted version of the image currently on the screen to start the display update process
        server.log("Sending new data to device, len: " + imgData.curImgInv.len());
        device.send("newImgStart", imgData.curImgInv);
      }
    } else {
      // Serve the WEB UI
      server.log("Trying to serve web ui");
      response.send(200, ui_html);
    }
}

http.onrequest(function(request, res) {
    server.log("Agent got new HTTP Request");
    // we need to set headers and respond to empty requests as they are usually preflight checks
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept");
    res.header("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

    if (request.path == "/WIFimage" || request.path == "/WIFimage/") {
    	// return right away to keep things responsive
    	res.send(200, "OK");

    	// incoming data has to be base64decoded so we can get a blob right away
    	local data = http.base64decode(request.body);
    	server.log("Got new data, len "+data.len());

    	// unpack the WIF image data
    	local newImgData = unpackWIF(data);
    	imgData.nxtImg = newImgData.normal;
    	imgData.nxtImgInv = newImgData.inverted;

    	// send the inverted version of the image currently on the screen to start the display update process
      server.log("Sending new data to device, len: "+imgData.curImgInv.len());
      device.send("newImgStart",imgData.curImgInv);
        
    } else if (request.path == "/clear" || request.path == "/clear/") {
    	res.send(200, "OK");
    	device.send("clear", 0);
    	// Clear our current image data so when we wipe it writes the correct
    	// inverted image
    	clear_blobs(imgData);
    	// Swap buffers
    	imgData.nxtImg = imgData.curImg;
    	imgData.nxtImgInv = imgData.curImgInv;
    	server.log("Requesting Screen Clear.");
    } else if (request.path == "/sleepfor" || request.path == "/sleepfor/") {
        server.log("Agent asked to sleep for "+request.body+" minute(s).");
        local sleeptime = 0;
        try {
            sleeptime = request.body.tointeger();
        } catch (err) {
            server.error("Invalid Time String Given to Sleep For: "+request.body);
            server.error(err);
            res.send(400, err);
            return;
        } 
        // allow max sleep time of one day. Sleep time comes in in minutes.
        if (sleeptime > 1440) { sleeptime = 1440; }
        device.send("sleepfor", (60 * sleeptime));
        res.send(200, format("Sleeping For %d seconds",(60 * sleeptime), request.body));
    } else if (request.path == "/sleepuntil" || request.path == "/sleepuntil/") {
        local sleeptime = 0;
        try {
            sleeptime = secondsTill(request.body);
        } catch (err) {
            server.error("Invalid Time String Given to Sleep Until: "+request.body);
            server.error(err);
            res.send(400, err);
            return;
        }
        device.send("sleepfor",sleeptime);
        res.send(200, format("Sleeping For %d seconds (until %s PST)", sleeptime, request.body));
    } else if (request.path == "/debug") {
      res.send(200, "Currrent Img Inv " + BlobToHexString(imgData.curImgInv) + "\n\n" +
                    "Current Actual " + BlobToHexString(imgData.curImg));
    } else {
      //webUIHandler(request, res);
      // @TODO(Sean) Update this to be cleaner, right now its a hack
    	// server.log("Agent got unknown request, ");
    	// server.log("Attempting to render image ");
    	testRequestImage();
      res.send(200, "Image");
    }
});