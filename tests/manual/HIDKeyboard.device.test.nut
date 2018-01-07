// MIT License
//
// Copyright 2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

// Setup
// ---------------------------------------------------------------------

// Test Hardware
//  - Imp005 Breakout Board
//  - Any USB keyboard


// Tests
// ---------------------------------------------------------------------

@include "USB.HID.device.lib.nut"
@include "examples/HID_Keyboard/HIDKeyboard.nut"

// HIDKeyboard driver test
// NOTE: The keyboard MUST support IDLE time setting, e.g. generate reports periodically
//       Otherwise the will fail with
class HIDKeyboardTest extends ImpTestCase {

    _host = null;

    _hid = null;

    _keyboard = null;

    function setUp() {
        _host = USB.Host([HIDKeyboard]);

        return "USB setup complete";
    }

    function test1() {

        local usbHost = this._host;
        local infoFunc = this.info.bindenv(this);

        return Promise(function(resolve, reject) {

            // report error if no device is attached
            local timer = imp.wakeup(1, function() {
                reject("No keyboard is attached");
            });


            usbHost.setEventListener(function(event, data) {
                if (event == "started") {
                    if (typeof data == "HIDKeyboard") {

                        imp.cancelwakeup(timer);

                        local numberOfPoll = 0;

                        // read data timeout
                        timer = imp.wakeup(3, function() {

                            data.stopPoll();

                            if (numberOfPoll > 4) reject("Too may report events");
                            else if (numberOfPoll > 2) resolve();
                            else reject("Invalid HID device poll period. Is the device real keyboard?");
                        });

                        infoFunc("Start keyboard polling. Press any button");

                        data.startPoll(100, function(keys) {
                            numberOfPoll++;
                        });

                    } else {
                        reject("Invalid driver is started: " + (typeof data));
                    }
                }
            });

            usbHost.reset();

        });
    }

    function tearDown() {
        hardware.usb.disable();

        _host = null;
    }

}