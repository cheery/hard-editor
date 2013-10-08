clamp = (low, high, value) ->
    return Math.max(low, Math.min(high, value))

inside = (element, {x, y}) ->
    dx = clamp(element.x, element.x+element.width, x) - x
    dy = clamp(element.y, element.y+element.height, y) - y
    return dx == 0 and dy == 0

roughPick = (element, position) ->
    if element.visible and inside(element, position)
        if element.inner?
            for frame in element.inner
                res = roughPick frame, position
                return res if res?
        return element

pick = (element, position) ->
    frame = roughPick(element, position)
    return unless frame?
    while (frame.type != 'flow') and frame.parent?
        frame = frame.parent
    return flowPick(frame, position)

findByRef = (element, ref) ->
    return element if element.ref == ref
    if element.inner?
        for frame in element.inner
            res = findByRef frame, ref
            return res if res?

createFrames = (frame, node, getStyle) ->
    frame.style = getStyle(node)
    frame.ref = node
    frame.type = frame.style.type
    frame.inner = []
    index = 0
    for child in node.children
        if typeof child == 'string'
            textGroupFrames frame.style.font, child, index, frame.inner
            index += child.length
        else
            subframe = {}
            createFrames subframe, child, getStyle
            frame.inner.push subframe
            index += 1
    return frame

class View
    constructor: (@getStyle, @document, @width) ->
        @root = createFrames {}, @document.root, @getStyle
        @layout()


        @document.onChange = (node, attrs) =>
            frame = findByRef(@root, node)
            createFrames frame, node, @getStyle
            @layout()

    layout: () ->
        flowLayout @root, @width
        flowPosition @root, 0, 0

    getKXLines: (node, index) ->
        frame = findByRef(@root, node)
        source = frame
        source = source.parent while source.type == 'inline'
        {k, x} = getKX(frame, source.lines, index)
        return {k, x, lines:source.lines}

jQuery -> canvasApp 'canvas#view', (canvas) ->
    canvas.width = 640
    ctx = canvas.getContext '2d'

    doc = createDocument( #createNode 'root', [
#        createNode 'h1', [
#            "Hello there"
#        ]
        createNode 'p', [
            "This is going to be an editor. It will support "
            createNode 'a', ["hyperlinks"]
            ". As well as media content between text."
        ]
    )
    window.doc = doc
#    ]

    h1Font = new Font(ctx, "32px 'Open Sans'", 32, 'black')
    h2Font = new Font(ctx, "24px 'Open Sans'", 24, 'black')
    blackFont = new Font(ctx, "16px 'Open Sans'", 16, 'black')
    blueFont = new Font(ctx, "16px 'Open Sans'", 16, 'blue')
    getStyle = (node) ->
        return switch node.label
            when 'h1' then {font:h1Font, type:"flow"}
            when 'h2' then {font:h2Font, type:"flow"}
            when 'p' then {font:blackFont, type:"flow"}
            when 'a' then {font:blueFont, type:"inline"}
            #when 'root' then {
            else throw "no type for this"

    view = new View(getStyle, doc, canvas.width)
#    root = {}
#    createFrames root, doc.root, getStyle
    selection = {
        node:doc.root, head:0, tail:0
        getRange: () ->
            return {
                start:Math.min(@head, @tail)
                stop:Math.max(@head, @tail)
            }
        setRange: (start, stop) ->
            if @head < @tail
                @head = start
                @tail = stop
            else
                @tail = start
                @head = stop
            @x = null
        insert: (data) ->
            {start,stop} = @getRange()
            @node.change(start, stop, data)
            @head = @tail = start + getChildrenLength(data)
            @x = null
    }

#
#    source  = "Act 1. Hello world hits you hard."
#    textGroupFrames blueFont, source, 0, frames=[]
#
#    element = {
#        type: 'inline'
#        inner: frames
#    }
#
#    source  = "Hello world.  Hello user. "
#    textGroupFrames blackFont, source, 0, frames=[]
#    index = source.length
#
#    frames.push element
#    index += 1
#
#    source  = " Hello Hello Hello Hello"
#    textGroupFrames blackFont, source, index, frames
#
#
#    root = {
#        type: 'flow'
#        inner:frames
#    }

    mouse = {x:0, y:0}
    sel = null
    $(canvas).mousemove (e) ->
        x = e.pageX - $(this).offset().left
        y = e.pageY - $(this).offset().top
        mouse = {x, y}
        sel = pick(view.root, mouse)

    $(canvas).mousedown (e) ->
        new_selection = pick(view.root, mouse)
        return unless new_selection?
        selection.node  = new_selection.frame.ref
        selection.head = new_selection.index
        selection.tail = new_selection.index

    $(canvas).keypress (e) ->
        string = String.fromCharCode(e.charCode)
        if string.length > 0
            selection.insert [string]

    $(canvas).keydown (e) ->
        if e.keyCode == 8
            {start, stop} = selection.getRange()
            selection.setRange(start-1, stop) if start == stop
            selection.insert []
        if e.keyCode == 46
            {start, stop} = selection.getRange()
            selection.setRange(start, stop+1) if start == stop
            selection.insert []

        if e.keyCode == 37 # left
            selection.head -= 1
            selection.tail = selection.head unless e.shiftKey
            selection.x = null
            
        if e.keyCode == 38 # up
            {k, x, lines} = view.getKXLines(selection.node, selection.head)
            selection.x ?= x
            if k > 0
                {frame, index} = scanClosestX(lines[k-1], x)
                selection.node = frame.ref
                selection.head = selection.tail = index

        if e.keyCode == 39 # right
            selection.head += 1
            selection.tail = selection.head unless e.shiftKey
            selection.x = null

        if e.keyCode == 40 # down
            {k, x, lines} = view.getKXLines(selection.node, selection.head)
            selection.x ?= x
            if k+1 < lines.length
                {frame, index} = scanClosestX(lines[k+1], x)
                selection.node = frame.ref
                selection.head = selection.tail = index

    do draw = () ->
        ctx.clearRect 0, 0, canvas.width, canvas.height
        render ctx, view.root
        ctx.fillStyle = "rgba(128,128,0,0.5)"

        if sel?
            ctx.strokeStyle = 'gray'
            ctx.strokeRect sel.frame.x, sel.frame.y, sel.frame.width, sel.frame.height
            ctx.fillStyle = "rgba(0,0,0,1.0)"
            drawFlowSelection ctx, sel.frame, sel.index, sel.index

        {start, stop} = selection.getRange()
        ctx.strokeStyle = 'gray'
        renderHighlight(ctx, view, selection.node)
        ctx.fillStyle = "rgba(0,0,255,0.5)"
        renderSelection(ctx, view, selection.node, start, stop)
        ctx.fillStyle = "rgba(0,0,0,1.0)"
        renderSelection(ctx, view, selection.node, selection.head, selection.head)

#        drawFlowSelection ctx, root, 0, window.stop
##        h2Font.render 'Act 1.', 0, 0
##        blackFont.render 'hello', 0, h2Font.height
##        blueFont.render 'world', 0, blackFont.height+h2Font.height


        requestAnimationFrame draw

renderHighlight = (ctx, view, node) ->
    frame = findByRef(view.root, node)
    return unless frame?
    ctx.strokeRect frame.x, frame.y, frame.width, frame.height

renderSelection = (ctx, view, node, start, stop) ->
    frame = findByRef(view.root, node)
    return unless frame?
    drawFlowSelection ctx, frame, start, stop

render = (ctx, element) ->
    return unless element.visible
    if element.type == 'fixed' or element.type == 'glue'
        element.font.render element.data, element.x, element.y
    if element.inner?
        for frame in element.inner
            render(ctx, frame)
