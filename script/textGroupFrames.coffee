characterGroup = (character) -> switch character
    when ' ' then 'glue'
    else 'fixed'

window.textGroupFrames = (font, text, index, frames) ->
    frames ?= []
    makeFrame = (group, string) ->
        {width, height, offsets} = font.measure(string)
        frames.push {
            type: group
            index: index
            data: string
            font: font
            min_width: width
            min_height: height
            width: width
            height: height
            offsets: offsets
        }
        index += string.length
    group = null
    string = ''
    flush = (new_group) ->
        if string.length > 0
            makeFrame group, string
            string = ''
        group = new_group
    for ch in text
        new_group = characterGroup(ch)
        flush(new_group) if new_group != group
        string += ch
    flush(group)
    return frames
