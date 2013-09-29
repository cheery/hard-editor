I've finally seen enough of html contenteditable and plaintext used for providing rich text editing. Those things seem to have zero capability to keep the document in valid form. By writing something completely apart from browsers I'll get full control into what is going on.

This project implements a custom document object model and renderer with simple layouter. It consists from three parts. On the name I got inspired from one contenteditable based editor project called 'medium-editor'. I think it's easier to do crap and destroy value than actually fix things so the name sort of describes my project relative to medium-editor, which doesn't do things quite _right_.

`script/document.coffee` provides a document model, which can be sliced and spliced (not across element boundaries though). The model holds a mechanism, which copies objects implicitly to avoid multiple parents in them.

`script/view.coffee` provides a view, which renders a document described above, also allows picking and highlighting of a selection from the document. The renderer assigns set of layouting commands for every frame it creates. Frames have 1:1 association with document nodes, but they're entirely contained within the renderer, only accessed by the layouter.

`script/breaklines.coffee` provides line wrapping code, which is compatible with the layouting techniques I use in the renderer. This far I only have a stupid row layouter, so the function of breakLines isn't visible in the demonstration.

Demonstration can be found from http://boxbase.org/hard-editor/ It still lacks a proper layout engine and editor controller, so it's not useful for everyone yet.
