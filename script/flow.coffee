window.flowLayout = (element, max_width) ->
    element.max_width = max_width
    element.inline = []
    element.lines = []
    frames = []
    do visit = (element) ->
        element.inline = []
        for frame in element.inner
            frame.parent = element
            switch frame.type
                when 'fixed', 'glue' then frames.push frame
                when 'inline'
                    element.inline.push frame
                    frames.push {type:'mark', width:0, height:0, offsets:[0], index:frame.index, parent:element}
                    visit frame
                    frames.push {type:'mark', width:0, height:0, offsets:[0], index:frame.index+1, parent:element}
                else
                    frames.push {type:'glue', width:0, height:0}
                    frames.push frame
                    frames.push {type:'glue', width:0, height:0}

    glues = []
    indices = []
    offsets = []
    offset = 0
    index = 0
    for frame in frames
        if frame.type == 'glue'
            glues.push frame
            offsets.push offset
            indices.push index
        offset += frame.width
        index += 1
    offsets.push offset

    badness = (Infinity for i in [0..glues.length])
    solution = (-1 for i in [0..glues.length])
    step = (start, base, preceding) ->
        first = start+1
        if offsets[first] - base > max_width # can't do anything in this situation, route around the damage.
            badness[first] = preceding
            solution[first] = start
            return
        for end in [first..glues.length]
            x = max_width - (offsets[end] - base)
            cost = if x < 0 then Infinity else x*x
            total = cost + preceding
            if total <= badness[end]
                badness[end] = total
                solution[end] = start
            if x < 0
                return
    step(-1, 0, 0)
    for i in [0...glues.length]
        step(i, offsets[i] + glues[i].width, badness[i])

    cutpoints = []
    cutpoint = solution[glues.length]
    while cutpoint > 0
        cutpoints.push indices[cutpoint]
        cutpoint = solution[cutpoint]

    if cutpoints.length == 0
        element.lines.push frames
    else
        lines = element.lines
        start = 0
        for i in [cutpoints.length-1..0]
            end = cutpoints[i]
            lines.push frames[start...end]
            start = end + 1
        lines.push frames[start...]

around = (element) ->
    visible = false
    x0 = x1 = y0 = y1 = null

    for frame in element.inner when frame.visible
        x2 = frame.x
        x3 = frame.x+frame.width
        y2 = frame.y
        y3 = frame.y+frame.height
        unless visible
            visible = true
            x0 = x2; x1 = x3; y0 = y2; y1 = y3
        x0 = Math.min(x0, x2)
        y0 = Math.min(y0, y2)
        x1 = Math.max(x1, x3)
        y1 = Math.max(y1, y3)
    if visible
        element.visible = true
        element.x = x0
        element.y = y0
        element.width  = x1-x0
        element.height = y1-y0


window.flowPosition = (element, x, y) ->
    element.visible = true
    element.x = x
    element.y = y
    for line in element.lines
        line.x = x = element.x
        line.y = y
        line.min_width = 0
        line.height = 10
        extend = 0
        for frame in line
            if frame.extend_width
                extend += 1
                line.min_width += frame.min_width
            else
                line.min_width += frame.width
            line.height = Math.max(line.height, frame.height)
        if extend > 0
            line.width = element.max_width
        else
            line.width = line.min_width
        extendf = (element.max_width - line.width) / extend
        for frame in line
            frame.visible = true
            frame.x = x
            frame.y = y
            frame.width = frame.min_width + extendf if frame.extend_width
            x += frame.width
        y += line.height
    element.width  = 0
    element.height = 0
    for line in element.lines
        element.width = Math.max(element.width, line.width)
        element.height += line.height
    do wrap = (element) ->
        for inline in element.inline
            around inline
            wrap inline

# these rest are used to draw and operate a selection.
window.getOffsets = (frame) ->
    offsets = frame.offsets
    offsets ?= [0, frame.width]
    return offsets

window.getKX = (element, lines, index) ->
    trail = null
    for k in [0...lines.length]
        line = lines[k]
        for frame in line
            continue unless frame.parent == element and frame.index?
            offsets = getOffsets(frame)
            if index < frame.index
                return {k, x:offsets[0]+frame.x}
            if index < frame.index + frame.offsets.length
                return {k, x:offsets[index - frame.index]+frame.x}
            trail = {k, x:frame.x+frame.width}
    return trail

window.drawFlowSelection = (ctx, element, start, stop) ->
    return unless element.type == 'inline' or element.type == 'flow'
    selection = (x0, x1, y, height) ->
        x1 += 1 if x0 == x1
        ctx.fillRect x0, y, x1-x0, height
        
    source = element
    source = source.parent while source.type == 'inline'
    {k:k0, x:x0} = getKX(element, source.lines, start)
    {k:k1, x:x1} = getKX(element, source.lines, stop)
    if k0==k1
        {y, height} = source.lines[k0]
        selection x0, x1, y, height
    else
        {x, y, width, height} = source.lines[k0]
        selection x0, x+width, y, height
        {x, y, width, height} = source.lines[k1]
        selection x, x1, y, height
        for k in [k0+1...k1]
            {x, y, width, height} = source.lines[k]
            selection x, x+width, y, height

clamp = (low, high, value) ->
    return Math.max(low, Math.min(high, value))

scanClosestY = (lines, y) ->
    line = lines[0]
    closest_y = Math.abs(clamp(line.y, line.y+line.height, y) - y)
    for k in [1...lines.length]
        line = lines[k]
        candi_y = Math.abs(clamp(line.y, line.y+line.height, y) - y)
        if closest_y <= candi_y
            return k-1
        else
            closest_y = candi_y
    return k-1

window.scanClosestX = (line, x) ->
    closest_x = Infinity
    last = null
    for frame in line when frame.index?
        offsets = getOffsets(frame)
        for k in [0...offsets.length]
            candi_x = Math.abs(frame.x+offsets[k] - x)
            if closest_x < candi_x
                return last
            else
                closest_x = candi_x
                last = {frame:frame.parent, index:frame.index+k}
    return last

window.flowPick = (element, position) ->
    k = scanClosestY(element.lines, position.y)
    return scanClosestX(element.lines[k], position.x)
