# makes it bit easier to write these apps
window.requestAnimationFrame ?= window.mozRequestAnimationFrame
window.requestAnimationFrame ?= window.webkitRequestAnimationFrame

window.canvasApp = (element, init) ->
    $(element).each ->
        init this
