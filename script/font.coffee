# I should get this information from a font library,
# so their computation belong in this wrapper.
class window.Font
    constructor: (@ctx, @font, @height, @color='black', @baseline) ->
        @baseline ?= @height * 0.75

    measure: (text) ->
        @ctx.font = @font
        offsets = [0]
        offset = 0
        for ch in text
            {width} = @ctx.measureText ch
            offsets.push offset += width
        return {
            width:offset
            height:@height
            offsets:offsets
        }

    render: (text, x, y) ->
        @ctx.font = @font
        @ctx.fillStyle = @color
        @ctx.fillText text, Math.floor(x), Math.floor(y+@baseline)
