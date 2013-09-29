# break single line into smaller lines.

window.breakLines = (nodes, max_width) ->
    glues = []
    indices = []
    offsets = []
    offset = 0
    index = 0
    for node in nodes
        if node.type == 'glue'
            glues.push node
            offsets.push offset
            indices.push index
        offset += node.width
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

    lines = []
    start = 0
    for i in [cutpoints.length-1..0]
        end = cutpoints[i]
        lines.push nodes[start...end]
        start = end + 1
    lines.push nodes[start...]
    return lines

