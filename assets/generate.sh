#!/bin/bash

set -e
#set -x

cd "$(CDPATH='' dirname "$0")"

# see https://fonts.google.com/icons?query=two+tone&icon.set=Material+Icons&icon.style=Two+tone
sym_font='fonts/MaterialIconsTwoTone-Regular.otf'
#text_font='fonts/Montserrat-Medium.ttf'
#text_font='fonts/Roboto-Regular.ttf'
text_font='fonts/Roboto_SemiCondensed-Regular.ttf'
#text_font='fonts/Roboto_SemiCondensed-Light.ttf'

global_args=(--bpp 2
             #--lcd
             --use-color-info)

join_by()
{
    local sep="$1"
    local first="$2"
    shift 2
    printf %s "$first" "${@/#/$sep}"
}

icon_unicodes=$(mktemp)
icon_names_to_range()
{
    local font="$1"
    shift
    local n name code
    local -a icon_range

    for n in "$@"
    do
        read -r name code < <(grep "^$n\>" "${font%.*}".codepoints)
        echo "    $n - \\u$code" >> "$icon_unicodes"
        icon_range+=("0x${code}")
    done
    join_by ',' "${icon_range[@]}"
}

chr()
{
    printf "\\$(printf '%03o' "$1")"
}

join()
{
    local sep="$1"
    local res=''
    shift
    if [ $# -gt 0 ]
    then
        local IFS=''
        res="${*/%/$sep}"
        res="${res::-${#sep}}"
    fi
    echo "$res"
}

ascii_range()
{
    local -a res=()
    local -a r
    local i
    local IFS
    while [ $# -gt 0 ]
    do
        if [[ $1 == ?-? ]]
        then
            IFS=- read -r -a r < <(echo "$1")
            res+=("$(printf "%d-%d" "'${r[0]}" "'${r[1]}")")
        else
            local i
            for ((i=0; i < ${#1}; i++));
            do
                res+=("$(printf "%d\n" "'${1:i:1}")")
            done
        fi
        shift
    done
    join ',' "${res[@]}"
}

utf8_encode()
{
    local utf=$(($1))
    if [ "$utf" -le $((0x7F)) ]
    then
        # Plain ASCII
        if [ "$utf" -ge 32 ] && [ "$utf" -lt $((0x7F)) ]
        then
            echo -n "$(chr "$utf")"
        else
            printf '\\u%02x' "$utf"
        fi
    elif [ "$utf" -le $((0x07FF)) ]
    then
        # 2-byte unicode
        printf '\\u%02x%02x' $((((utf >> 6) & 0x1F) | 0xC0)) \
                             $((((utf >> 0) & 0x3F) | 0x80))
    elif [ "$utf" -le $((0xFFFF)) ]
    then
        # 3-byte unicode
        printf '\\u%02x%02x%02x' $((((utf >> 12) & 0x0F) | 0xE0)) \
                                 $((((utf >> 6) & 0x3F) | 0x80)) \
                                 $((((utf >> 0) & 0x3F) | 0x80))
    elif [ "$utf" -le $((0x10FFFF)) ]
    then
        # 4-byte unicode
        printf '\\u%02x%02x%02x%02x' $((((utf >> 18) & 0x07) | 0xF0)) \
                                     $((((utf >> 12) & 0x3F) | 0x80)) \
                                     $((((utf >> 6) & 0x3F) | 0x80)) \
                                     $((((utf >> 0) & 0x3F) | 0x80))
    else
        # error - use replacement character
        printf '\\uEFBFBD'
    fi
}

# shellcheck disable=SC2034 # variable name is auto-detected
specific_args_huge_symbols=(
    --size 64
    --no-kerning
    --font "${sym_font}"
    --range "$(icon_names_to_range "${sym_font}" local_fire_department wb_sunny bedtime pan_tool power_settings_new)"
)

# shellcheck disable=SC2034 # variable name is auto-detected
specific_args_title_symbols=(
    --size 46
    --no-kerning
    --font "${sym_font}"
    --range "$(icon_names_to_range "${sym_font}" speed timeline toggle_on)"
)

# shellcheck disable=SC2034 # variable name is auto-detected
specific_args_medium=(
    --size 36
    --font "${text_font}"
    --symbols ',.-°CF% ÄÜÖäöüß'
    --range "$(ascii_range 0-9 A-Z a-z)"
    --font "${sym_font}"
    --range "$(icon_names_to_range "${sym_font}" thermostat water_drop screen_lock_landscape)"
)

# shellcheck disable=SC2034 # variable name is auto-detected
specific_args_big_num=(
    --size 100
    #--no-kerning
    --font "${text_font}"
    --symbols '0123456789,.-'
)

docker build -q -t lvcont . >/dev/null

tmpout='out.bin'
rm -Rf "$tmpout" fontinfo

for conf in "${!specific_args_@}"
do
    declare -n reference="$conf"
    name="${conf#specific_args_}"
    echo "generating $name"
    docker run -it -v .:/data lvcont --output "$tmpout" --format bin "${global_args[@]}" "${reference[@]}"
    if which montage &>/dev/null
    then
        rm -Rf fontinfo
        rm -f "${name}.png"
        mkdir fontinfo
        docker run -it -v .:/data lvcont --output fontinfo --format dump "${global_args[@]}" "${reference[@]}"
        (
            cd fontinfo
            magick montage -label '%f' -frame 5 -background '#ffffff' -geometry 70x70+4+4 *.png "../${name}.png"
        )
        rm -Rf fontinfo
    fi
    rm -f "${name}.font"
    cat "$tmpout" > "${name}.font"
    rm -f "$tmpout"
done

echo "Symbol codes:"
cat "$icon_unicodes"
rm -f "$icon_unicodes"
