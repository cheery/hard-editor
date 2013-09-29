class GlueFrame
    type: 'glue'
    constructor: (@parent, @base, {@width, @height, @offsets}) ->
    draw: (view) ->
        if @visible
            @parent.layout.drawGlue.call(@parent, view, this)
    layout: {
        measure: -> @visible = false
        position: (@x, @y) -> @visible = true
    }

class TextFrame
    type: 'text'
    constructor: (@parent, @base, @text, {@width, @height, @offsets}) ->
    draw: (view) ->
        if @visible
            @parent.layout.drawText.call(@parent, view, this)
    layout: {
        measure: -> @visible = false
        position: (@x, @y) -> @visible = true
    }

class Frame
    type: 'frame'
    constructor: (@parent, @base, @node, @children) ->
    draw: (view) ->
        return unless @visible
        @layout.draw.call(this, view)
        for frame in @children
            frame.draw(view)

genFrame = (view, parent, base, node, layoutinfo) ->
    frame = new Frame(parent, base, node, frames = [])
    offset = 0
    shard = (base, shard, glue) ->
        frames.push if glue
            new GlueFrame(frame, base, view.measureText(shard))
        else
            new TextFrame(frame, base, shard, view.measureText(shard))
    for i in [0...len = node.children.length]
        child = node.children[i]
        firstchild = (i == 0)
        lastchild  = (i == len - 1)
        if typeof child == 'string'
            textShards offset, child, shard
            offset += child.length
        else
            frames.push new GlueFrame(frame, null, {width:0, height:0}) unless firstchild
            frames.push genFrame(view, frame, offset, child, {firstchild, lastchild})
            frames.push new GlueFrame(frame, null, {width:0, height:0}) unless lastchild
            offset += 1
    frame.layout = view.getLayout frame, layoutinfo
    return frame

class View
    constructor: (@ctx, @document) ->
        @root = genFrame this, null, null, @document.root, {}
        console.log @root

    measureText: (text) ->
        offsets = [0]
        offset = 0
        for ch in text
            {width} = @ctx.measureText ch
            offsets.push offset += width
        return {
            width:offset
            height:@ctx.font_height
            offsets:offsets
        }

    getLayout: (frame, {firstchild, lastchild}) -> stdLayout

    update: (x, y, max_width, max_height) ->
        @root.layout.measure.call(@root, max_width, max_height)
        @root.layout.position.call(@root, x, y)

    draw: () ->
        @root.draw(@)

    pick: (x, y) ->
        rec = (node) ->
            return if node.type != 'frame'
            for child in node.children
                return res if (res = rec(child))?
            return node if inside(node, x, y)
        node = rec(@root)
        return unless node?
        best_dist = Infinity
        index = 0
        for child in node.children
            continue unless child.offsets? and child.base? and child.visible
            relx = x - child.x
            dy = Math.round(clamp(child.y, child.y+child.width, y) - y)
            base = child.base
            for offset in child.offsets
                dx = Math.round(relx - offset)
                dist = dx*dx + dy*dy
                if dist <= best_dist
                    index = base
                    best_dist = dist
                base += 1
        return {frame:node, node:node.node, index}

    getFrame: (node) ->
        rec = (frame) ->
            return frame if frame.node == node
            for child in frame.children when child.type == 'frame'
                    return res if (res = rec(child))?
        return rec @root

    drawSelection: ({node, start, stop}) ->
        frame = @getFrame node
        return unless frame?
        frame.layout.drawSelection.call(frame, this, start, stop)

window.View = View

stdLayout = {
    measure: (max_width, max_height) ->
        @visible = false
        offset = 0
        @height = 10
        for child in @children
            child.layout.measure.call(child, max_width, max_height)
            offset += child.width
            @height = Math.max(@height, child.height)
        @width = Math.max(offset, 10)
        @width  += 8
        @height += 8
    position: (@x, @y) ->
        @visible = true
        offset = 0
        for child in @children
            child.layout.position.call(child, 4+@x+offset, 4+@y+(@height-8-child.height)/2)
            offset += child.width
    draw: (view) ->
        view.ctx.strokeRect(@x, @y, @width, @height)
    drawGlue: (view, frame) ->
    drawText: (view, frame) ->
        view.ctx.fillText frame.text, frame.x, frame.y+view.ctx.font_height
    drawSelection: (view, start, stop) ->
        view.ctx.strokeRect(@x+4, @y+4, @width-8, @height-8)
        x0 = null
        x1 = null
        for child in @children when child.base?
            x0 ?= getOffset(child, start)
            x1 ?= getOffset(child, stop)
        return unless x0? and x1?
        view.ctx.strokeRect(x0, @y+4, x1-x0, @height-8)
}

getOffset = (frame, index) ->
    return unless frame.base?
    offsets = frame.offsets
    offsets ?= [0, frame.width]
    offset = offsets[index - frame.base]
    return frame.x + offset if offset?

inside = (rect, x, y) ->
    x -= clamp(rect.x, rect.x+rect.width, x)
    y -= clamp(rect.y, rect.y+rect.height, y)
    return x == 0 and y == 0

clamp = (floor, ceil, value) -> Math.min(ceil, Math.max(floor, value))

textShards = (base, text, callback) ->
    isWhite = (ch) -> ch == ' '
    mode = false
    buffer = ''
    flush = (new_mode) ->
        if (len = buffer.length) > 0
            callback base - len, buffer, mode
            buffer = ''
        mode = new_mode
    for ch in text
        if (new_mode = isWhite(ch)) != mode
            flush(new_mode)
        buffer += ch
        base += 1
    flush(new_mode)
