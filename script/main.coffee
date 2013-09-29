drawNothing = (ctx) ->
drawText = (ctx) ->
    if @visible
        ctx.fillText @data, @x, @y+@height

wordSegments = (ctx, text) ->
    glue = ctx.measureText(' ')
    genGlue = () -> {
        type:'glue'
        width:glue.width
        height:ctx.font_height
        draw: drawNothing
    }
    genWord = (text) -> {
        type:'word'
        width:ctx.measureText(text).width
        height:ctx.font_height
        data: text
        draw: drawText
    }
    words = text.split(' ')
    segments = [genWord(words[0])]
    for i in [1...words.length]
        segments.push genGlue()
        if words[i].length > 0 then segments.push genWord(words[i])
    return segments

layoutRow = (nodes, b_x, b_y) ->
    for node in nodes
        node.x = b_x
        node.y = b_y
        node.visible = true
        b_x += node.width

$ ->
    #mkdoc root
    #mknod label, children
    #doc.onChange = (node, changes) ->
    #node.change start, stop, data

    canvas = $('#view')[0]
    canvas.width  = 800
    canvas.height = 600
    ctx = canvas.getContext '2d'
    ctx.font = "16px 'Open Sans'"
    ctx.font_height = 16

    
    doc = mkdoc mknod 'root', [
        mknod 'p', ["hello there."]
        mknod 'p', [
            "this is an"
            mknod 'link', ['editable component']
            "in front of you"
        ]
        mknod 'p', ["with it's own DOM"]
    ]
    view = new View(ctx, doc)
    
    source_text = "This_is_an_example on minimum_raggedness_word_wrapping. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer euismod vulputate nulla, sit amet feugiat turpis gravida eu. Pellentesque eu nulla ac erat consequat sagittis sed sed nisl. Aenean a varius justo. Vestibulum ullamcorper, tellus eu consectetur fermentum, lacus nibh elementum velit, non commodo tellus urna quis enim. Duis massa turpis, tincidunt non ante eu, tempus molestie lacus. Quisque faucibus condimentum laoreet. Nullam eu malesuada justo, at porta magna. Morbi molestie dignissim enim, id venenatis velit faucibus sed. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Suspendisse sodales a metus id ultrices. Quisque ornare fermentum purus non feugiat. Aenean ac arcu justo. Nullam sed vestibulum quam."
    nodes = wordSegments(ctx, source_text)

    window.requestAnimationFrame ?= window.mozRequestAnimationFrame
    window.requestAnimationFrame ?= window.webkitRequestAnimationFrame

    selection = {node:doc.root, start:0, stop:0}

    draw = () ->
        ctx.clearRect 0, 0, canvas.width, canvas.height
        view.update(10, 10, canvas.width, canvas.height)
        view.draw()
        view.drawSelection selection

#        x = 0
#        line_width = Math.floor(500 + Math.cos(Date.now() / 5000) * 250)
#        ctx.fillRect x + line_width, 0, 1, canvas.height
#        rows = breakLines nodes, line_width
#        i = 0
#        for row in rows
#            layoutRow row, x, i*16
#            i += 1
#        for node in nodes
#            node.draw(ctx)
        requestAnimationFrame draw
    draw()

    $(canvas).mousemove (e) ->
        details = view.pick e.offsetX, e.offsetY
        if details?
            selection.node = details.node
            selection.start = selection.stop = details.index
        else
            selection.node = null
