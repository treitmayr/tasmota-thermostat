import lv

class lv_switch_mqtt: lv.switch

    var _remote_name
    var _prepare_enable
    var _text_checked
    var _text_unchecked
    var _lv_label

    def init(parent)
        super(self).init(parent)

        # start disabled
        self.add_state(lv.STATE_DISABLED)

        # get informed about user actions
        self.add_event_cb( / obj, event -> self._switch_changed(obj, event), lv.EVENT_VALUE_CHANGED, 0)

        # track connected state to enable/disable the switch
        tasmota.add_rule("Mqtt#Connected", / -> self._mqtt_connect())
        tasmota.add_rule("Mqtt#Disconnected", / -> self._mqtt_disconnect())
    end

    def get_remote(name)
        return self._remote_name
    end

    def set_remote(name)
        import mqtt
        if self._remote_name
            mqtt.unsubscribe(self._get_topic("stat", "RESULT"))
            self._mqtt_disconnect()
        end
        self._remote_name = name
        if self._remote_name
            mqtt.subscribe(self._get_topic("stat", "RESULT"),
                           / topic,idx,payload_s -> self._mqtt_result(topic,idx,payload_s))
            self._mqtt_connect()
        end
    end

    # similar to lvh_obj.check_label()
    def _check_label()
        if self._lv_label == nil
            # create a sub-label object
            self._lv_label = lv.label(self)
            self._lv_label.set_align(lv.ALIGN_CENTER);
        end
    end

    def set_text_checked(text)
        self._check_label()
        self._text_checked = str(text)
        self._update_text()
    end

    def set_text_unchecked(text)
        self._text_unchecked = str(text)
        self._update_text()
    end

    def _update_text(state)
        if self._lv_label == nil
            return
        end
        if state == nil
            state = self.has_state(lv.STATE_CHECKED)
        end
        if state && self._text_checked != nil
            self._lv_label.set_text(self._text_checked)
        elif !state && self._text_unchecked != nil
            self._lv_label.set_text(self._text_unchecked)
        end
    end

    def _switch_changed(obj, event)
        import mqtt
        var state = self.has_state(lv.STATE_CHECKED)
        self._update_text(state)
        mqtt.publish(self._get_topic("cmnd", "Power"), state ? "ON" : "OFF")
    end

    def _mqtt_result(topic, idx, payload_s)
        import json
        var res = json.load(payload_s)
        if res && res.contains("POWER")
            if res["POWER"] == "ON"
                self.add_state(lv.STATE_CHECKED)
                self._update_text(true)
            else
                self.clear_state(lv.STATE_CHECKED)
                self._update_text(false)
            end
            if self._prepare_enable
                # enable the switch
                self.clear_state(lv.STATE_DISABLED)
                self._prepare_enable = false
            end
        end
    end

    def _mqtt_connect()
        if self._remote_name
            import mqtt
            # query the current power state
            mqtt.publish(self._get_topic("cmnd", "Power"), "")
            self._prepare_enable = true
        end
    end

    def _mqtt_disconnect()
        # disable the switch
        self.add_state(lv.STATE_DISABLED)
        self._prepare_enable = false
    end

    def _get_topic(kind, name)
        return f"{kind}/{self._remote_name}/{name}"
    end

end

return lv_switch_mqtt
