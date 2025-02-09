import ch422g

class waveshare_lcd_43_driver

    # values for set_AD_usage()
    static var DIG_OUT = 0
    static var DIG_INP = 1
    static var ANA_OUT = 2
    static var ANA_INP = 3

    # CH422G: Set default output according to measurements and the schematic:
    #   EXIO0 .. NC, low
    #   EXIO1 .. CTP_RST, high
    #   EXIO2 .. DISP, high
    #   EXIO3 .. LCD_RST, pull-up
    #   EXIO4 .. SDCS, pull-up
    #   EXIO5 .. USB_SEL, low
    #   EXIO6+7 .. NC
    static var _exio_default = 0x1e
    static var _exio_disp_off = 0x1a

    static var _gpio_AD = 6

    var _exio
    var _dev_idx
    var _dev_state

    def init()
        self._exio = ch422g()
        self._exio.set_to_output(self._exio_default)

        tasmota.add_driver(self)
    end

    def set_AD_usage(usage, init)
        if usage == self.DIG_OUT
            self._dev_idx = tasmota.global.devices_present
            tasmota.global.devices_present += 1
            gpio.pin_mode(self._gpio_AD, gpio.OUTPUT)
            self._dev_state = init ? 1 : 0
            gpio.digital_write(self._gpio_AD, self._dev_state)
        else
            # more to support soon
        end
    end

    def get_AD_power_index()
        var ret
        if self._dev_idx != nil
            ret = self._dev_idx + 1
        end
        return ret
    end

    def set_power_handler(cmd, idx)
        if self._dev_idx != nil
            var new_state = (idx >> self._dev_idx) & 0x01
            print(f"{self._dev_idx=} {idx=} {new_state=}")
            if new_state != self._dev_state
                gpio.digital_write(self._gpio_AD, new_state)
                self._dev_state = new_state
            end
        end
    end

    # respond to display events
    def display(cmd, idx, payload, raw)
        print(f"display {cmd=} {idx=}")
        if cmd == "dim" || cmd == "power"
            self._set_disp_dimmer(int(idx))
        end
    end

    # dimmer value in percent
    def _set_disp_dimmer(pct)
        # we can only turn on or off the display due to the board design
        if pct <= 30
            self._exio.set_to_output(self._exio_disp_off)
            #self._exio.sleep()
        else
            # BIG NOTE:
            # There seems to be something wrong with re-enabling the display via the DISP pin!
            # Observations with the following screensaver configuration:
            #     "berry_on":"global.ex_io.set_output_pin(2,true)","berry_off":"global.ex_io.set_output_pin(2,false)"
            #     => Turning the display back on leads to a restart of the CPU after ~0.5 s after the display has turned on.
            #        Also the USB serial connection (to a PC) is lost! Maybe there the sudden load of the LCD backlight
            #        driver + LCD controller cause a VCC breakdown or ground bounce???
            # Workaround:
            # Turning on has to be done by flipping the pins to the input direction, i.e.
            #     "berry_on":"global.ex_io.set_to_input()","berry_off":"global.ex_io.set_to_output(0x1a)"
            self._exio.set_to_input()         # this already turns on the display
            tasmota.delay(2)                 # wait a bit to avoid current rush-in
            #self._exio.set_to_output(self._exio_default)
            #self._exio.sleep()
        end
    end
end

return waveshare_lcd_43_driver
