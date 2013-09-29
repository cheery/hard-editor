# this is quite simple stuff
# If node does not belong into a document, it is considered free.
# Free nodes are adopted by nodes that catch them first.
# adoption into already adopted node returns duplicates.

class Document
    constructor: (@root) ->
        @root.adopt @

    onChange: (node, {start, stop, inserted, deleted}) ->

class Node
    constructor: (@label, @children, @length) ->
        @parent = null

    slice: (start, stop) -> split(@children, start, stop)[1]
    change: (start, stop, inserted) ->
        inserted ?= []
        inserted = adopt inserted, this
        [prefix, deleted, postfix] = split(@children, start, stop)
        @children = merge(prefix, inserted, postfix)
        for node in deleted when typeof node == 'object'
            node.parent = null
        @length = getLength(@children)
        @getDocument()?.onChange @, {start, stop, inserted, deleted}
        return deleted

    adopt: (new_parent) ->
        node = @
        if node.parent == null
            node.parent = new_parent
        else if node.parent != new_parent
            node = node.duplicate()
            node.parent = new_parent
        return node
    
    duplicate: () ->
        node = new Node(@label)
        node.children = adopt @children, node
        node.length = getLength(node.children)
        return node

    getDocument: () ->
        current = @parent
        while current != null
            unless current instanceof Node
                return current
            current = current.parent
        return current

window.mkdoc = (root) -> new Document(root)

window.mknod = (label, children) ->
    children ?= []
    length = getLength(children)
    new Node(label, children, length)

adopt = (children, new_parent) ->
    for node in children
        if typeof node == 'string'
            node = node
        else if node.parent == null
            node.parent = new_parent
        else if node.parent != new_parent
            node = node.duplicate()
            node.parent = new_parent
        node

getLength = (children) ->
    offset = 0
    for child in children
        if typeof child == 'string'
            offset += child.length
        else
            offset += 1
    return offset

split = (children, indices...) ->
    chop = (children, index) ->
        offset = 0
        for i in [0...children.length]
            child = children[i]
            if typeof child == 'string'
                offset += child.length
            else
                offset += 1
            if offset == index
                return [
                    children.slice(0, i)
                    children.slice(i)
                ]
            if index < offset + length
                cut = index - offset
                lhs = children.slice(0, i)
                rhs = children.slice(i+1)
                lhs.splice i, 0, child.slice(0, cut)
                rhs.splice 0, 0, child.slice(cut)
                return [lhs, rhs]
            offset += length
        return [children.slice(), []]
    offset = 0
    out = for index in indices
        [prefix, children] = chop children, index - offset
        offset += index
        prefix
    out.push children
    return out

merge = (head, rest...) ->
    for tail in rest
        if tail.length == 0
            continue
        else if head.length == 0
            head = tail
            continue
        mid = head.length
        head = head.concat tail
        if typeof head[mid-1] == 'string' and typeof head[mid] == 'string'
            head.splice(mid-1, 2, head[mid-1] + head[mid])
    return head
