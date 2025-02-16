class aura_button : lv.btn

    def init(parent)
        super(self).init(parent)

        var st = lv.style()
        st.set_radius(3)        # TODO: Fully round sides

        st.set_bg_opa(lv.OPA_COVER)
        st.set_bg_color(lv.palette_main(lv.PALETTE_BLUE))
        st.set_bg_grad_color(lv.palette_darken(lv.PALETTE_BLUE, 2))
        st.set_bg_grad_dir(lv.GRAD_DIR_VER)

        st.set_border_opa(lv.OPA_40)
        st.set_border_width(2)
        st.set_border_color(lv.palette_main(lv.PALETTE_GREY))

        st.set_shadow_width(8)
        st.set_shadow_color(lv.palette_main(lv.PALETTE_GREY))
        #st.set_shadow_offset_y(8)
        st.set_shadow_ofs_y(8)

        st.set_outline_opa(lv.OPA_COVER)
        st.set_outline_color(lv.palette_main(lv.PALETTE_BLUE))

        st.set_text_color(lv.color_white())
        st.set_pad_all(10)

        # pressed style
        var st_pr = lv.style()

        # add a large outline when pressed
        st_pr.set_outline_width(30)
        st_pr.set_outline_opa(lv.OPA_TRANSP)
        #st_pr.set_outline_opa(lv.OPA_40)

        st_pr.set_translate_y(5)
        st_pr.set_shadow_offset_y(3)
        st_pr.set_bg_color(lv.palette_darken(lv.PALETTE_BLUE, 2))
        st_pr.set_bg_grad_color(lv.palette_darken(lv.PALETTE_BLUE, 4))

        # add a transition to the outline
        #var props = lv.style_prop_arr([lv.STYLE_OUTLINE_WIDTH, lv.STYLE_OUTLINE_OPA, 0])
        #print(f"{props=}")
        var trans = lv.style_transition_dsc([lv.STYLE_OUTLINE_WIDTH, lv.STYLE_OUTLINE_OPA, 0], lv.anim_path_linear, 300, 0, nil)
        import global
        global.trans = trans
        #print(f"{trans.props=} {trans.path_xcb=} {trans.time=} {trans.delay=}")
          #trans.init(props, lv.anim_path_linear, 300, 0)
          #trans.init(props, nil, lv.anim_path_linear, 1000, 0)
          #var trans = lv.style_transition_dsc(props, lv.anim_path_linear, 300, 0)
          #var trans = lv.style_transition_dsc(props, lv.anim_path_linear, 300, 0, nil)
        #style_transition_dsc_init(trans, props, lv.anim_path_linear, 300, 0, nil)
        #trans.props = [lv.STYLE_OUTLINE_WIDTH, lv.STYLE_OUTLINE_OPA, 0]
        #var prop_arr = lv.style_prop_arr([lv.STYLE_OUTLINE_WIDTH, lv.STYLE_OUTLINE_OPA, 0])
        #print(f"{prop_arr=}")
        #print(f"{prop_arr.toint()=}")
        #print(f"{trans.props=}")
        #import global
        #global.prop_arr = prop_arr
        #trans.props = global.prop_arr
        #trans.props = [lv.STYLE_OUTLINE_WIDTH, lv.STYLE_OUTLINE_OPA, 0]
        #trans.user_data = nil
        #trans.path_xcb = lv.anim_path_linear
        #trans.time = 300
        #trans.delay = 0
        #print(f"{trans.props=} {trans.time=} {trans.delay=}")

        st_pr.set_transition(trans)

        self.remove_style_all()           # remove the style coming from the theme
        self.add_style(st, 0)
        self.add_style(st_pr, lv.STATE_PRESSED)
        self.set_size(lv.SIZE_CONTENT, lv.SIZE_CONTENT)
        self.center()

        #self.refresh_style(lv.PART_ANY, lv.STYLE_PROP_ANY)    # ??
    end

end

return aura_button
