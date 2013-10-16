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
    if frame.type != 'flow' and frame.type != 'inline'
        return
    return flowPick(frame, position)

findByRef = (element, ref) ->
    return element if element.ref == ref
    if element.inner?
        for frame in element.inner
            res = findByRef frame, ref
            return res if res?

createFrames = (frame, element, getStyle) ->
    frame.style = getStyle(element)
    frame.ref = element
    frame.type = frame.style.type
    frame.inner = []
    if element.text.length > 0
        textGroupFrames frame.style.font, element.text, 0, frame.inner
    for child in element.list
        subframe = {index:child.index}
        createFrames subframe, child, getStyle
        frame.inner.push subframe
        if child.tail.length > 0
            textGroupFrames frame.style.font, child.tail, child.index+1, frame.inner
    if frame.inner.length == 0
        textGroupFrames getStyle(null).font, "<#{element.label}>", 0, frame.inner
        frame.inner[frame.inner.length-1].offsets = [0]
    return frame

class View
    constructor: (@getStyle, @document, @width) ->
        @root = createFrames {}, @document, @getStyle
        @layout()

    onChange: (element, details) ->
        frame = findByRef(@root, element)
        createFrames frame, element, @getStyle
        @layout()

    layout: () ->
        for frame in @root.inner
            flowLayout frame, @width
        @root.x = 0
        @root.y = 0
        @root.visible = true
        y = 0
        height = 0
        for frame in @root.inner
            flowPosition frame, 0, y
            y += frame.height + 10
            height += frame.height + 10
        @root.width = @width
        @root.height = height

    getKXLines: (node, index) ->
        frame = findByRef(@root, node)
        source = frame
        source = source.parent while source.type == 'inline'
        {k, x} = getKX(frame, source.lines, index)
        return {k, x, lines:source.lines}

startRenderer = (editor) ->
    {canvas, ctx, document} = editor
    h1Font = new Font(ctx, "32px 'Open Sans'", 32, 'black')
    h2Font = new Font(ctx, "24px 'Open Sans'", 24, 'black')
    blackFont = new Font(ctx, "16px 'Open Sans'", 16, 'black')
    blueFont = new Font(ctx, "16px 'Open Sans'", 16, 'blue')
    redFont = new Font(ctx, "16px 'Open Sans'", 16, 'red')
    getStyle = (element) ->
        return {font:redFont} if element == null
        return switch element.label
            when 'h1' then {font:h1Font, type:"flow"}
            when 'h2' then {font:h2Font, type:"flow"}
            when 'p' then {font:blackFont, type:"flow"}
            when 'a' then {font:blueFont, type:"inline"}
            when 'document' then {font:blackFont, type:"column"}
            else throw "no type for this"

    view = new View(getStyle, document, canvas.width/2)

    render = (frame) ->
        return unless frame.visible
        if frame.type == 'fixed' or frame.type == 'glue'
            frame.font.render frame.data, frame.x, frame.y
        if frame.inner?
            for subframe in frame.inner
                render(subframe)

    highlight = (element) ->
        frame = findByRef(view.root, element)
        return unless frame? and frame.visible
        ctx.fillRect frame.x, frame.y, frame.width, frame.height

    flowmark = (element, start, stop=start) ->
        frame = findByRef(view.root, element)
        return unless frame? and frame.visible
        drawFlowSelection ctx, frame, start, stop

    draw = () ->
        ctx.clearRect 0, 0, canvas.width, canvas.height
        ctx.fillStyle = "rgba(128,128,0,0.5)"
        render view.root

        if editor.selection?
            ctx.fillStyle = "rgba(0,0,0, 0.05)"
            highlight(editor.selection.element)
            {start, stop} = editor.selection.getRange()

            ctx.fillStyle = "rgba(0,0,255,0.5)"
            flowmark(editor.selection.element, start, stop)
            ctx.fillStyle = "rgba(0,0,0,1.0)"
            flowmark(editor.selection.element, editor.selection.head)

        ctx.fillStyle = "rgba(128,128,128, 1.0)"
        ctx.fillRect canvas.width/2, 0, canvas.width/2, canvas.height

        requestAnimationFrame draw
    draw()
    return view

startMouse = (editor) ->
    state = {x:0, y:0}
    from = null
    till = null

    redefine_selection = () ->
        return unless from?
        editor.selection.element = from.frame.ref
        editor.selection.tail = from.index
        editor.selection.head = from.index
        return unless till?
        e0 = from.frame.ref
        i0 = from.index
        e1 = till.frame.ref
        i1 = till.index
        if e0 is e1
            editor.selection.tail = i0
            editor.selection.head = i1
        else if (common = dom.commonParent(e0, e1, i0, i1))?
            editor.selection.element = common.element
            if common.index0?
                tail = common.index0
            else
                tail = i0
            if common.index1?
                head = common.index1
            else
                head = i1
            if head < tail and common.index0?
                tail += 1
            if tail < head and common.index1?
                head += 1
            editor.selection.tail = tail
            editor.selection.head = head

    $(editor.canvas).mousemove (e) ->
        state.x = e.pageX - $(this).offset().left
        state.y = e.pageY - $(this).offset().top

        if state.down
            till = pick(editor.view.root, state)
            redefine_selection()

    $(editor.canvas).mousedown (e) ->
        e.preventDefault()
        from = till = pick(editor.view.root, state)
        redefine_selection()
        state.down = true

    $(editor.canvas).mouseup (e) ->
        e.preventDefault()
        state.down = false

startKeyboard = (editor) ->
    translator = {
        8: 'backspace'
        9: 'tab'
        13: 'enter'
        16: 'shift'
        17: 'ctrl'
        18: 'alt'
        27: 'escape'
        32: 'space'
        35: 'end'
        36: 'home'
        37: 'left'
        38: 'up'
        39: 'right'
        40: 'down'
        45: 'insert'
        46: 'delete'
    }
    modes = (e) -> {shift:e.shiftKey, ctrl:e.ctrlKey, alt:e.altKey}
    $(editor.canvas).keypress (e) ->
        e.preventDefault()
        char = String.fromCharCode(e.charCode)
        if char != "" and e.charCode != 13
            editor.keyboardCharacter char, modes(e)
    $(editor.canvas).keydown  (e) ->
        key = translator[e.which]
        if key?
            e.preventDefault()
            editor.keyboardResponse key, modes(e)

climbTree = (element, labels) ->
    while labels.indexOf(element.label) == -1
        element = element.parent
        return unless element?
    return element

flattenThese = (element, labels) ->
    for subelement in element.list
        flattenThese(subelement, labels)
        if labels.indexOf(subelement.label) >= 0
            index = subelement.index
            element.kill(index, index+1)
            element.put(index, subelement)
    return element


block_labels = ['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6']

class Editor
    constructor: (element, @document) ->
        canvasApp element, (@canvas) =>
            @canvas.width  = 1024
            @canvas.height = 640
            @ctx = @canvas.getContext '2d'
            @view = startRenderer(this)

            target = @document
            target = target.list[0] while target.list[0]? and target.text.length == 0
            @selection = new Selection(target, 0, 0)
            $(@canvas).focus()
            startMouse(this)
            startKeyboard(this)

    lineReshape: (new_label) ->
        element = climbTree(@selection.element, block_labels)
        if element?
            element.label = 'p'
            @selection.element.label = new_label
            @view.onChange(element, {})

    elementWrap: (label, illegal_over, illegal_inside) ->
        element = climbTree(@selection.element, illegal_over)
        unless element?
            {start, stop} = @selection.getRange()
            element = @selection.element
            buffer = element.kill(start, stop)
            buffer.label = label
            flattenThese(buffer, illegal_inside)
            element.insert(start, buffer)
            @selection.element = element.getElementByIndex(start)
            @selection.setRange(0, @selection.element.bot)
#
#
#
#            @selection.element = dom.createElement(label)
#            element.insert(start, @selection.element)
#            @selection.element.put(0, buffer)
            @view.onChange(element, {})

    canSplit: () ->
        for element in @selection.element.getPath()
            if block_labels.indexOf(element.label) != -1
                return true

    splitLine: () ->
        return unless @canSplit()

        @selection.discard()
        element = @selection.element
        head = @selection.head

        while block_labels.indexOf(element.label) == -1
            new_line = element.kill(head, element.bot)
            new_line.label = element.label
            element.parent.insert(element.index+1, new_line)
            head = element.index+1
            element = element.parent


        new_line = element.kill(head, element.bot)
        new_line.label = 'p'
        element.parent.insert(element.index+1, new_line)

        @selection.element = element.parent.getElementByIndex(element.index+1)
        @selection.head = @selection.tail = 0

        @view.onChange(element.parent, {})
#        new_line = element.kill(@selection.head, element.bot)
#        new_line.label = element.label
#            index = element.index+1
#            element = element.parent
#            new_element = new_line
#            new_line = element.kill(index, element.bot)
#            new_line.insert(0, new_element)
#        element.index
#        element.parent

    removeStyle: (labels) ->
        flattenThese(@selection.element, labels)
        @view.onChange(@selection.element, {})

    merge: (side) ->
        if side == 'left' and @selection.element.previousSibling?
            element = @selection.element.previousSibling.remove()
            @selection.element.put(0, element)
            @selection.head = element.bot
            @selection.tail = element.bot
            @view.onChange(@selection.element.parent, {})
        else if side == 'right' and @selection.element.nextSibling?
            element = @selection.element.nextSibling.remove()
            @selection.element.put(@selection.element.bot, element)
            @view.onChange(@selection.element.parent, {})

    keyboardCharacter: (char) ->
        if @tabEscape
            switch char
                when '0' then @lineReshape 'p'
                when '1' then @lineReshape 'h1'
                when '2' then @lineReshape 'h2'
                when 'a' then @elementWrap 'a', ['a'], ['a']
                when 'c' then @removeStyle ['a']
            @tabEscape = false
        else
            @selection.insertText char
            @view.onChange(@selection.element, {})

    keyboardResponse: (key, modes) ->
        switch key
            when 'tab'
                @tabEscape = true
            when 'backspace'
                if @selection.isTop()
                    @merge('left')
                else
                    @selection.discard('left')
                    @view.onChange(@selection.element, {})
            when 'delete'
                if @selection.isBot()
                    @merge('right')
                else
                    @selection.discard('right')
                    @view.onChange(@selection.element, {})
            when 'space'
                @selection.insertText " "
                @view.onChange(@selection.element, {})
            when 'enter'
                @splitLine()
            else
                console.log 'keyboard response', key, modes

##     $(canvas).keypress (e) ->
##         string = String.fromCharCode(e.charCode)
##         if string.length > 0
##             selection.insert dom.createElement(null).append(string)
##         selection.normalize()

class Selection
    constructor: (@element, @head=0, @tail=0) ->
        
    getRange: () ->
        return {
            start:Math.min(@head, @tail)
            stop:Math.max(@head, @tail)
        }
    setRange: (start, stop) ->
        start = clamp(0, @element.bot, start)
        stop  = clamp(0, @element.bot, stop)
        if @head < @tail
            @head = start
            @tail = stop
        else
            @tail = start
            @head = stop
        @x = null

    isTop: () ->
        return @tail == 0 and @head == 0

    isBot: () ->
        bot = @element.bot
        return @tail == bot and @head == bot

    discard: (mode) ->
        {start, stop} = @getRange()
        start -= 1 if start == stop and mode == 'left'
        stop  += 1 if start == stop and mode == 'right'
        start = clamp(0, @element.bot, start)
        stop  = clamp(0, @element.bot, stop)
        @element.kill(start, stop)
        @setRange(start, start)

    insertText: (text) ->
        {start, stop} = @getRange()
        @element.kill(start, stop)
        @element.insertText(start, text)
        @head = @tail = start + text.length

##         setRange: (start, stop) ->
##             @setRangeUnsafe start, stop
##             @normalize()
##         insert: (data) ->
##             {start,stop} = @getRange()
##             nof = start + data.bot
##             @element.kill(start, stop) if start != stop
##             @element.put(start, data)
##             view.onChange(@element, {start, stop, data})
##             @head = @tail = nof
##             @x = null
## 
##             #@node.change(start, stop, data)
##             #@head = @tail = start + getChildrenLength(data)
##             #@x = null
##         normalize: () ->
##             top = 0
##             bot = @element.bot
##             {start, stop} = @getRange()
##             start = clamp(top, bot, start)
##             stop = clamp(top, bot, stop)
##             @setRangeUnsafe start, stop
##         neighbours: () ->
##             prefix = @node.slice 0, @head
##             postfix = @node.slice @head, @node.length
##             lhs = prefix[prefix.length-1]
##             rhs = postfix[0]
##             lhs = null if typeof lhs == 'string'
##             rhs = null if typeof rhs == 'string'
##             return {lhs, rhs}
##     }


jQuery ->
    document = dom.createElement('document', null, "", [
        dom.createElement('h1').append("Hello there")
        dom.createElement('p')
            .append("This is going to be an editor. It will support ")
            .append(dom.createElement('a').append("hyperlinks"))
            .append(". As well as media content between text.")
    ])
    editor = new Editor('canvas#view', document)
    window.editor = editor


## jQuery -> canvasApp 'canvas#view', (canvas) ->
##     under_label = (node, label) ->
##         while node?
##             return true if node.label == label
##             node = node.parent
##         return false
## 
##     $(canvas).keydown (e) ->
##         if e.ctrlKey and e.keyCode == 65 and not under_label(selection.node, 'a')
##             {start, stop} = selection.getRange()
##             new_node = createNode 'a', selection.node.slice(start, stop)
##             selection.insert [new_node]
##             selection.node = new_node
##             selection.setRange(0, new_node.length)
## 
##         if e.keyCode == 8
##             {start, stop} = selection.getRange()
##             selection.setRange(start-1, stop) if start == stop
##             selection.insert []
##         if e.keyCode == 46
##             {start, stop} = selection.getRange()
##             selection.setRange(start, stop+1) if start == stop
##             selection.insert []
## 
##         if e.keyCode == 37 # left
##             {lhs, rhs} = selection.neighbours()
##             if lhs? and not e.shiftKey
##                 selection.node = lhs
##                 selection.head = selection.tail = lhs.length
##             else if selection.head == 0 and selection.node.parent? and selection.node.parent.label?
##                 parent = selection.node.parent
##                 head = parent.indexOf(selection.node)
##                 selection.node = parent
##                 selection.head = selection.tail = head
##                 selection.tail += 1 if e.shiftKey
##             else
##                 selection.head -= 1
##                 selection.tail = selection.head unless e.shiftKey
##                 selection.x = null
##             
##         if e.keyCode == 38 # up
##             {k, x, lines} = view.getKXLines(selection.node, selection.head)
##             selection.x ?= x
##             if k > 0
##                 {frame, index} = scanClosestX(lines[k-1], selection.x)
##                 selection.node = frame.ref
##                 selection.head = selection.tail = index
##             else
##                 parent = selection.node.parent
##                 index = parent.indexOf(selection.node)
##                 if index > 0
##                     node = parent.children[index-1] # works only if it's a list
## 
## 
##         if e.keyCode == 39 # right
##             {lhs, rhs} = selection.neighbours()
##             if rhs? and not e.shiftKey
##                 selection.node = rhs
##                 selection.head = selection.tail = 0
##             else if selection.head == selection.node.length and selection.node.parent? and selection.node.parent.label?
##                 parent = selection.node.parent
##                 head = parent.indexOf(selection.node) + 1
##                 selection.node = parent
##                 selection.head = selection.tail = head
##                 selection.tail -= 1 if e.shiftKey
##             else
##                 selection.head += 1
##                 selection.tail = selection.head unless e.shiftKey
##                 selection.x = null
## 
##         if e.keyCode == 40 # down
##             {k, x, lines} = view.getKXLines(selection.node, selection.head)
##             selection.x ?= x
##             if k+1 < lines.length
##                 {frame, index} = scanClosestX(lines[k+1], selection.x)
##                 selection.node = frame.ref
##                 selection.head = selection.tail = index
##         selection.normalize()
## 
