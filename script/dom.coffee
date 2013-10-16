class Element
    constructor: (@label, @uid, @text, @list, @tail) ->
        @updateList()

    copy: () ->
        list = (element.copy() for element in @list)
        return new Element(@label, @uid, @text, list, @tail)

    # iteration: @list
    # length: @list.length
    # get: @list[index]
    # set: @list[index]=, @updateList()

    getElementByIndex: (index) ->
        for element in @list
            return element if element.index == index

    indexOf: (element) ->
        return @list.indexOf element

    updateList: () ->
        index = @text.length
        for i in [0...@list.length]
            element = @list[i]
            element.parent = this
            element.index = index
            element.previousSibling = @list[i-1]
            element.nextSibling     = @list[i+1]
            index += element.tail.length + 1
        @firstChild = @list[0]
        @lastChild = @list[index-1]
        @bot = index

    append: (element) ->
        if typeof element == 'string'
            return @appendText(element)
        throw "element already attached" if element.parent?
        @list.push(element)
        element.parent = this
        element.index = @bot
        @bot += element.tail.length + 1
        return this

    appendText: (text) ->
        k = @list.length
        @setText(k, @getText(k) + text)
        @bot += text.length
        return this

    remove: () ->
        @parent.kill(@index, @index+1)
        return this

    toString: () ->
        inner = @text
        for element in @list
            inner += element.toString()
        if @uid?
            return "<#{@label} uid=#{@uid}>#{inner}</#{@label}>#{@tail}"
        else
            return "<#{@label}>#{inner}</#{@label}>#{@tail}"

    translateIndex: (index) ->
        if index <= @text.length
            return {k:0, i:Math.max(index, 0)}
        res = {k:0, i:@text.length}
        for k in [1..@list.length]
            element = @list[k-1]
            i = index - element.index - 1
            if i <= element.tail.length
                return {k, i}
            res.i = element.tail.length
        return res

    getText: (k) ->
        if k == 0
            return @text
        else
            return @list[k-1].tail

    setText: (k, text) ->
        if k == 0
            @text = text
        else
            @list[k-1].tail = text

    yank: (start, stop) ->
        {k:k0, i:i0} = @translateIndex(start)
        {k:k1, i:i1} = @translateIndex(stop)
        
        text = @getText(k0)[i0...]
        tail = @getText(k1)[...i1]

        list = (element.copy() for element in @list[k0...k1])

        yanked = new Element(null, null, text, list, "")
        yanked.setText(list.length, tail)
        return yanked

    kill: (start, stop) ->
        {k:k0, i:i0} = @translateIndex(start)
        {k:k1, i:i1} = @translateIndex(stop)

        tail = @getText(k1)
        @setText(k1, tail[...i1])
        head = @getText(k0)
        @setText(k0, head[...i0] + tail[i1...])

        removed = new Element(null, null, head[i0...], @list[k0...k1], "")
        @list[k0...k1] = []
        @updateList()
        return removed

    put: (index, buff) ->
        {k, i} = @translateIndex(index)
        buff = buff.copy()

        text = @getText(k)
        tail = text[i...]

        buff.appendText(tail)
        @setText(k, text[...i] + buff.text)
        @list[k...k] = buff.list
        @updateList()
        return null

    insertText: (index, text) ->
        @put index, new Element(null, null, text, [], "")

    insert: (index, element) ->
        if typeof element == 'string'
            return @appendText(element)
        throw "element already attached" if element.parent?
        @put index, new Element(null, null, "", [element], "")

    getPath: () ->
        path = []
        element = this
        while element?
            path.push element
            element = element.parent
        return path.reverse()

dom = {
    createElement: (label=null, uid=null, text="", list=[], tail="") ->
        return new Element(label, uid, text, list, tail)
    commonParent: (a, b) ->
        A = a.getPath()
        B = b.getPath()
        m = Math.min(A.length, B.length)
        while m > 0 and not (A[m-1] is B[m-1])
            m -= 1
        if m == A.length
            return {element:A[m-1], index0:null, index1:B[m].index}
        if m == B.length
            return {element:B[m-1], index0:A[m].index, index1:null}
        if m > 0
            return {element:A[m-1], index0:A[m].index, index1:B[m].index}
        return null
}

window.dom = dom
