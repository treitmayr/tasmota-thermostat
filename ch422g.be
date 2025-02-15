class ch422g

    static var _def_i2c_addr = 0x24      # see https://github.com/esp-arduino-libs/ESP32_IO_Expander/blob/e79a63876a1d8a834cf8ec8f8b698ff9d9374579/src/port/esp_io_expander_ch422g.h#L41

    static var _reg_wr_set = 0x48 >> 1   # 0x24, Set System Parameter Command
    static var _reg_wr_oc  = 0x46 >> 1   # 0x23, Set General-Purpose Output Command
    static var _reg_wr_io  = 0x70 >> 1   # 0x38, Set Bidirectional I/O Command
    static var _reg_rd_io  = 0x4D >> 1   # 0x26, Read Bidirectional I/O Command

    var _wire

    var _cur_wr_set
    var _cur_wr_oc
    var _cur_wr_io

    def init(opt_addr)
        var i2c_addr = (opt_addr == nil) ? self._def_i2c_addr : opt_addr
        self._wire = tasmota.wire_scan(i2c_addr)
        if !self._wire
            tasmota.log(f"Cannot find CH422G IO Expander at I2C address {i2c_addr}")
        end
    end

    # set all GPIO pins to output with the given pin states
    def set_to_output(state, use_open_drain)
        # first prepare the output state
        self.set_outputs(state)

        # then enable output
        self._cur_wr_set = 0x01
        if use_open_drain
            self._cur_wr_set |= 0x10
        end
        self._write_to(self._reg_wr_set, self._cur_wr_set)
    end

    # set all GPIO pins to input
    def set_to_input()
        self._cur_wr_set = 0x00
        self._write_to(self._reg_wr_set, self._cur_wr_set)
    end

    # set all GPIO to the given output states (assumes that pins are in output mode already)
    def set_outputs(state)
        self._cur_wr_io = state & 0xff
        self._cur_wr_oc = (state & 0xf00) >> 8

        self._write_to(self._reg_wr_io, self._cur_wr_io)
        self._write_to(self._reg_wr_oc, self._cur_wr_oc)
    end

    # set a single GPIO to the given output state (assumes that pins are in output mode already)
    def set_output_pin(pin, state)
        var mask
        if pin >= 0 && pin < 8
            mask = 1 << pin
            if state
                self._cur_wr_io |= mask
            else
                self._cur_wr_io &= ~mask
            end
            print(f"{self._cur_wr_io=}")
            self._write_to(self._reg_wr_io, self._cur_wr_io)
        elif pin >= 8 && pin < 12
            mask = 1 << (pin - 8)
            if state
                self._cur_wr_oc |= mask
            else
                self._cur_wr_oc &= ~mask
            end
            self._write_to(self._reg_wr_oc, self._cur_wr_oc)
        else
            tasmota.log(f"Pin number out of range (expected: [0-11], actual {pin}", 1)
        end
    end

    # return the current input state of the GPIO (assumes that pins are in input mode already)
    def get_inputs()
        return self._read_from(self._reg_rd_io)
    end

    # return the current input state of a single GPIO (assumes that pins are in input mode already)
    def get_input_pin(pin)
        var ret
        var mask
        if pin >= 0 && pin < 8
            mask = 1 << pin
            ret = bool(self._read_from(self._reg_rd_io) & mask)
        else
            tasmota.log(f"Pin number out of range (expected: [0-7], actual {pin}", 1)
        end
        return ret
    end

    # switch CH422G to sleep mode
    def sleep()
        self._cur_wr_set |= 0x80
        self._write_to(self._reg_wr_set, self._cur_wr_set)
    end

    # wake up CH422G from sleep mode
    def wake_up()
        self._cur_wr_set &= ~0x80
        self._write_to(self._reg_wr_set, self._cur_wr_set)
    end

    # I2C read access
    def _read_from(addr)
        var ret
        self._wire._request_from(addr, 1)
        if self._wire._available()
           ret = self._wire._read()
        end
        self._wire._end_transmission(true)
        return ret
    end

    # I2C write access
    def _write_to(addr, b)
        self._wire._begin_transmission(addr)
        self._wire._write(b)
        self._wire._end_transmission()
    end

end

return ch422g
