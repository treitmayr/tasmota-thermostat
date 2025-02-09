class avg_interval

    var _winlen        # length of window [ms]
    var _winend        # end of sample window
    var _scnt          # sample count
    var _sum           # sample sum

    def init()
        self.set_interval(1)
    end

    def set_interval(secs)
        self._winlen = secs * 1000 - 200          # -200 ms to account for event processing
        self._winend = tasmota.millis(self._winlen)
        self._scnt = 0
        self._sum = 0.0
        return self
    end

    def add_value(val)
        var result
        self._sum += val
        self._scnt += 1
        if tasmota.time_reached(self._winend)
            self._winend = tasmota.millis(self._winlen)          # set new end of measurement window
            result = self._sum / self._scnt
            self._scnt = 0
            self._sum = 0.0
        end
        return result
    end
end

return avg_interval
