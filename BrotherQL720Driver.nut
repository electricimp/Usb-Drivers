class BrotherQL720Driver extends DriverBase {

    static VID = 0x04f9;
    static PID = 0x2044;
    static QL720_REQUEST_QL720_OUT = 0x40;
    static QL720_SIO_SET_BAUD_RATE = 3;
    static QL720_SIO_SET_FLOW_CTRL = 2;
    static QL720_SIO_DISABLE_FLOW_CTRL = 0;


    // Commands
    static CMD_ESCP_ENABLE = "\x1B\x69\x61\x00";
    static CMD_ESCP_INIT = "\x1B\x40";

    static CMD_SET_ORIENTATION = "\x1B\x69\x4C"
    static CMD_SET_TB_MARGINS = "\x1B\x28\x63\x34\x30";
    static CMD_SET_LEFT_MARGIN = "\x1B\x6C";
    static CMD_SET_RIGHT_MARGIN = "\x1B\x51";

    static CMD_ITALIC_START = "\x1b\x34";
    static CMD_ITALIC_STOP = "\x1B\x35";
    static CMD_BOLD_START = "\x1b\x45";
    static CMD_BOLD_STOP = "\x1B\x46";
    static CMD_UNDERLINE_START = "\x1B\x2D\x31";
    static CMD_UNDERLINE_STOP = "\x1B\x2D\x30";

    static CMD_SET_FONT_SIZE = "\x1B\x58\x00";
    static CMD_SET_FONT = "\x1B\x6B";

    static CMD_BARCODE = "\x1B\x69"
    static CMD_2D_BARCODE = "\x1B\x69\x71"

    static LANDSCAPE = "\x31";
    static PORTRAIT = "\x30";

    // Special characters
    static TEXT_NEWLINE = "\x0A";
    static PAGE_FEED = "\x0C";

    // Font Parameters
    static ITALIC = 1;
    static BOLD = 2;
    static UNDERLINE = 4;

    static FONT_SIZE_24 = 24;
    static FONT_SIZE_32 = 32;
    static FONT_SIZE_48 = 48;

    static FONT_BROUGHAM = 0;
    static FONT_LETTER_GOTHIC_BOLD = 1;
    static FONT_BRUSSELS = 2;
    static FONT_HELSINKI = 3;
    static FONT_SAN_DIEGO = 4;

    // Barcode Parameters
    static BARCODE_CODE39 = "t0";
    static BARCODE_ITF = "t1";
    static BARCODE_EAN_8_13 = "t5";
    static BARCODE_UPC_A = "t5";
    static BARCODE_UPC_E = "t6";
    static BARCODE_CODABAR = "t9";
    static BARCODE_CODE128 = "ta";
    static BARCODE_GS1_128 = "tb";
    static BARCODE_RSS = "tc";
    static BARCODE_CODE93 = "td";
    static BARCODE_POSTNET = "te";
    static BARCODE_UPC_EXTENTION = "tf";

    static BARCODE_CHARS = "r1";
    static BARCODE_NO_CHARS = "r0";

    static BARCODE_WIDTH_XXS = "w4";
    static BARCODE_WIDTH_XS = "w0";
    static BARCODE_WIDTH_S = "w1";
    static BARCODE_WIDTH_M = "w2";
    static BARCODE_WIDTH_L = "w3";

    static BARCODE_RATIO_2_1 = "z0";
    static BARCODE_RATIO_25_1 = "z1";
    static BARCODE_RATIO_3_1 = "z2";

    // 2D Barcode Parameters
    static BARCODE_2D_CELL_SIZE_3 = "\x03";
    static BARCODE_2D_CELL_SIZE_4 = "\x04";
    static BARCODE_2D_CELL_SIZE_5 = "\x05";
    static BARCODE_2D_CELL_SIZE_6 = "\x06";
    static BARCODE_2D_CELL_SIZE_8 = "\x08";
    static BARCODE_2D_CELL_SIZE_10 = "\x0A";

    static BARCODE_2D_SYMBOL_MODEL_1 = "\x01";
    static BARCODE_2D_SYMBOL_MODEL_2 = "\x02";
    static BARCODE_2D_SYMBOL_MICRO_QR = "\x03";

    static BARCODE_2D_STRUCTURE_NOT_PARTITIONED = "\x00";
    static BARCODE_2D_STRUCTURE_PARTITIONED = "\x01";

    static BARCODE_2D_ERROR_CORRECTION_HIGH_DENSITY = "\x01";
    static BARCODE_2D_ERROR_CORRECTION_STANDARD = "\x02";
    static BARCODE_2D_ERROR_CORRECTION_HIGH_RELIABILITY = "\x03";
    static BARCODE_2D_ERROR_CORRECTION_ULTRA_HIGH_RELIABILITY = "\x04";

    static BARCODE_2D_DATA_INPUT_AUTO = "\x00";
    static BARCODE_2D_DATA_INPUT_MANUAL = "\x01";


    _deviceAddress = null;
    _controlEndpoint = null;
    _bulkIn = null;
    _bulkOut = null;
    _buffer = null; // buffer for building text


    constructor(usb) {
        _buffer = blob();
        base.constructor(usb);
    }

    function initialize() {
        write(CMD_ESCP_ENABLE); // Select ESC/P mode
        write(CMD_ESCP_INIT); // Initialize ESC/P mode
        return this;
    }

    function _typeof() {
        return "BrotherQL720Driver";
    }

    function _setupEndpoints(deviceAddress, speed, descriptors) {
        server.log(format("Driver connecting at address 0x%02x", deviceAddress));
        _deviceAddress = deviceAddress;
        _controlEndpoint = ControlEndpoint(_usb, deviceAddress, speed, descriptors["maxpacketsize0"]);

        // Select configuration
        local configuration = descriptors["configurations"][0];
        server.log(format("Setting configuration 0x%02x (%s)", configuration["value"], _controlEndpoint.getStringDescriptor(configuration["configuration"])));
        _controlEndpoint.setConfiguration(configuration["value"]);

        // Select interface
        local interface = configuration["interfaces"][0];
        local interfacenumber = interface["interfacenumber"];

        foreach (endpoint in interface["endpoints"]) {
            local address = endpoint["address"];
            local maxPacketSize = endpoint["maxpacketsize"];
            if ((endpoint["attributes"] & 0x3) == 2) {
                if ((address & 0x80) >> 7 == USB_DIRECTION_OUT) {
                    _bulkOut = BulkOutEndpoint(_usb, speed, _deviceAddress, interfacenumber, address, maxPacketSize);
                } else {
                    _bulkIn = BulkInEndpoint(_usb, speed, _deviceAddress, interfacenumber, address, maxPacketSize);
                }
            }
        }
    }

    function getIdentifiers() {
        local identifiers = {};
        identifiers[VID] <-[PID];
        return [identifiers];
    }

    function _configure(device) {
        server.log(format("Configuring for device version 0x%04x", device));

        // Set Baud Rate
        local baud = 115200;
        local baudValue;
        local baudIndex = 0;
        local divisor3 = 48000000 / 2 / baud; // divisor shifted 3 bits to the left

        if (device == 0x0100) { // FT232AM
            if ((divisor3 & 0x07) == 0x07) {
                divisor3++; // round x.7/8 up to x+1
            }

            baudValue = divisor3 >> 3;
            divisor3 = divisor3 & 0x7;

            if (divisor3 == 1) {
                baudValue = baudValue | 0xc000; // 0.125
            } else if (divisor3 >= 4) {
                baudValue = baudValue | 0x4000; // 0.5
            } else if (divisor3 != 0) {
                baudValue = baudValue | 0x8000; // 0.25
            }

            if (baudValue == 1) {
                baudValue = 0; /* special case for maximum baud rate */
            }

        } else {
            local divfrac = [0, 3, 2, 0, 1, 1, 2, 3];
            local divindex = [0, 0, 0, 1, 0, 1, 1, 1];

            baudValue = divisor3 >> 3;
            baudValue = baudValue | (divfrac[divisor3 & 0x7] << 14);

            baudIndex = divindex[divisor3 & 0x7];

            /* Deal with special cases for highest baud rates. */
            if (baudValue == 1) {
                baudValue = 0; // 1.0
            } else if (baudValue == 0x4001) {
                baudValue = 1; // 1.5
            }
        }
        // server.log("Baud rate is:"+baudValue);
        baudValue = 9600;
        _controlEndpoint.send(QL720_REQUEST_QL720_OUT, QL720_SIO_SET_BAUD_RATE, baudValue, baudIndex);

        local xon = 0x11;
        local xoff = 0x13;

        _controlEndpoint.send(QL720_REQUEST_QL720_OUT, QL720_SIO_SET_FLOW_CTRL, xon | (xoff << 8), QL720_SIO_DISABLE_FLOW_CTRL << 8);
    }

    function _start() {
        _bulkIn.read(blob(1));
    }

    function write(data) {
        local _data = null;

        if (typeof data == "string") {
            _data = blob();
            _data.writestring(data);
        } else if (typeof data == "blob") {
            _data = data;
        } else {
            server.error("Write data must of type string or blob");
            return;
        }
        _bulkOut.write(_data);
    }

    function connect(deviceAddress, speed, descriptors) {
        _setupEndpoints(deviceAddress, speed, descriptors);
        _start();
    }

    function transferComplete(eventdetails) {
        local direction = (eventdetails["endpoint"] & 0x80) >> 7;
        if (direction == USB_DIRECTION_IN) {
            local readData = _bulkIn.done(eventdetails);

            if (readData.len() >= 3) {
                readData.seek(2);
                onEvent("data", readData.readblob(readData.len()));
            }
            // Blank the buffer
            // _bulkIn.read(blob(64 + 2));
        } else if (direction == USB_DIRECTION_OUT) {
            _bulkOut.done(eventdetails);
        }
    }

    // Formating commands
    function setOrientation(orientation) {
        // Create a new buffer that we prepend all of this information to
        local orientationBuffer = blob();

        // Set the orientation
        orientationBuffer.writestring(CMD_SET_ORIENTATION);
        orientationBuffer.writestring(orientation);

        write(orientationBuffer);

        return this;
    }


    function setRightMargin(column) {
        return _setMargin(CMD_SET_RIGHT_MARGIN, column);
    }

    function setLeftMargin(column) {
        return _setMargin(CMD_SET_LEFT_MARGIN, column);;
    }

    function setFont(font) {
        if (font < 0 || font > 4) throw "Unknown font";

        _buffer.writestring(CMD_SET_FONT);
        _buffer.writen(font, 'b');

        return this;
    }

    function setFontSize(size) {
        if (size != 24 && size != 32 && size != 48) throw "Invalid font size";

        _buffer.writestring(CMD_SET_FONT_SIZE)
        _buffer.writen(size, 'b');
        _buffer.writen(0, 'b');

        return this;
    }

    // Text commands
    function writeToBuffer(text, options = 0) {
        local beforeText = "";
        local afterText = "";

        if (options & ITALIC) {
            beforeText += CMD_ITALIC_START;
            afterText += CMD_ITALIC_STOP;
        }

        if (options & BOLD) {
            beforeText += CMD_BOLD_START;
            afterText += CMD_BOLD_STOP;
        }

        if (options & UNDERLINE) {
            beforeText += CMD_UNDERLINE_START;
            afterText += CMD_UNDERLINE_STOP;
        }

        _buffer.writestring(beforeText + text + afterText);

        return this;
    }

    function writen(text, options = 0) {
        return writeToBuffer(text + TEXT_NEWLINE, options);
    }

    function newline(lines = 1) {
        for (local i = 0; i < lines; i++) {
            writeToBuffer(TEXT_NEWLINE);
        }
        return this;
    }

    // Barcode commands
    function writeBarcode(data, config = {}) {
        // Set defaults
        if (!("type" in config)) { config.type <- BARCODE_CODE39; }
        if (!("charsBelowBarcode" in config)) { config.charsBelowBarcode <- true; }
        if (!("width" in config)) { config.width <- BARCODE_WIDTH_XS; }
        if (!("height" in config)) { config.height <- 0.5; }
        if (!("ratio" in config)) { config.ratio <- BARCODE_RATIO_2_1; }

        // Start the barcode
        _buffer.writestring(CMD_BARCODE);

        // Set the type
        _buffer.writestring(config.type);

        // Set the text option
        if (config.charsBelowBarcode) {
            _buffer.writestring(BARCODE_CHARS);
        } else {
            _buffer.writestring(BARCODE_NO_CHARS);
        }

        // Set the width
        _buffer.writestring(config.width);

        // Convert height to dots
        local h = (config.height * 300).tointeger();
        // Set the height
        _buffer.writestring("h"); // Height marker
        _buffer.writen(h & 0xFF, 'b'); // Lower bit of height
        _buffer.writen((h / 256) & 0xFF, 'b'); // Upper bit of height

        // Set the ratio of thick to thin bars
        _buffer.writestring(config.ratio);

        // Set data
        _buffer.writestring("\x62");
        _buffer.writestring(data);

        // End the barcode
        if (config.type == BARCODE_CODE128 || config.type == BARCODE_GS1_128 || config.type == BARCODE_CODE93) {
            _buffer.writestring("\x5C\x5C\x5C");
        } else {
            _buffer.writestring("\x5C");
        }

        return this;
    }

    function write2dBarcode(data, config = {}) {
        // Set defaults
        if (!("cell_size" in config)) { config.cell_size <- BARCODE_2D_CELL_SIZE_3; }
        if (!("symbol_type" in config)) { config.symbol_type <- BARCODE_2D_SYMBOL_MODEL_2; }
        if (!("structured_append_partitioned" in config)) { config.structured_append_partitioned <- false; }
        if (!("code_number" in config)) { config.code_number <- 0; }
        if (!("num_partitions" in config)) { config.num_partitions <- 0; }

        if (!("parity_data" in config)) { config["parity_data"] <- 0; }
        if (!("error_correction" in config)) { config["error_correction"] <- BARCODE_2D_ERROR_CORRECTION_STANDARD; }
        if (!("data_input_method" in config)) { config["data_input_method"] <- BARCODE_2D_DATA_INPUT_AUTO; }

        // Check ranges
        if (config.structured_append_partitioned) {
            config.structured_append <- BARCODE_2D_STRUCTURE_PARTITIONED;
            if (config.code_number < 1 || config.code_number > 16) throw "Unknown code number";
            if (config.num_partitions < 2 || config.num_partitions > 16) throw "Unknown number of partitions";
        } else {
            config.structured_append <- BARCODE_2D_STRUCTURE_NOT_PARTITIONED;
            config.code_number = "\x00";
            config.num_partitions = "\x00";
            config.parity_data = "\x00";
        }

        // Start the barcode
        _buffer.writestring(CMD_2D_BARCODE);

        // Set the parameters
        _buffer.writestring(config.cell_size);
        _buffer.writestring(config.symbol_type);
        _buffer.writestring(config.structured_append);
        _buffer.writestring(config.code_number);
        _buffer.writestring(config.num_partitions);
        _buffer.writestring(config.parity_data);
        _buffer.writestring(config.error_correction);
        _buffer.writestring(config.data_input_method);

        // Write data
        _buffer.writestring(data);

        // End the barcode
        _buffer.writestring("\x5C\x5C\x5C");

        return this;
    }

    // Text commands
    function _print(text, options = 0) {
        local beforeText = "";
        local afterText = "";

        if (options & ITALIC) {
            beforeText += CMD_ITALIC_START;
            afterText += CMD_ITALIC_STOP;
        }

        if (options & BOLD) {
            beforeText += CMD_BOLD_START;
            afterText += CMD_BOLD_STOP;
        }

        if (options & UNDERLINE) {
            beforeText += CMD_UNDERLINE_START;
            afterText += CMD_UNDERLINE_STOP;
        }

        _buffer.writestring(beforeText + text + afterText);

        return this;
    }

    // Prints the label
    function print() {
        _buffer.writestring(PAGE_FEED);
        write(_buffer);

        _buffer = blob();
    }

    function _setMargin(command, margin) {
        local marginBuffer = blob();
        marginBuffer.writestring(command);
        marginBuffer.writen(margin & 0xFF, 'b');

        write(marginBuffer);

        return this;
    }

}
