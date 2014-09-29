corona-sdk-snippets
===================

Installation: git clone --recursive https://github.com/ggcrunchy/corona-sdk-snippets.git

Various bits and pieces, written either as components of a game or out of mere curiosity.

After the intro, select a sample from the listbox in the upper left corner and hit "Launch".

Many samples have a short explanation, shown in the marquee at the bottom. I'll try to improve these
as time goes on.

Most of the demos right now are just automatic. In "Nodes", the boxes may be dragged around, lines may be
dragged between the nodes, and the links that result may then be broken. A few samples provide widgets that
allow for changing some setting or other. In "Timers", much of the output goes to the console, and what's
happening is probably less than obvious to someone not actually reading the code itself to see the flow.
"ColoredCorners" and "Seams" are legitimate tools and could probably constitute an app or two on their own.

"Game" compromises some bits excerpted from a game in progress (well, at some point it was, anyhow :( ). The
"player" is the white dot, who can be controlled in several ways: with the buttons in the bottom left, by
double-tapping a spot on the map, or using the cursor keys (in the simulator)... and some input devices, at
least on Android. A button also appears when you're over a warp or switch, in order to use those. Currently,
I've only added a maze generator to go with the switch.

Also, you can set some debug stuff in the Options screen, from the main menu, as well as wipe any persisent
state, namely any levels you've saved in the editor.

"Editor" is likewise part of an editor for the same game. There is a lot going on, and I haven't documented
much. Maybe later I'll describe how to use it. :P (It is not pretty; I'm attempting at least somewhat of a
redesign, at present.) If by some chance you puzzle it out, you can hit "Test" to try the level out (at a
minimum, a starting cell must be assigned in the "Player" view). Erroneous levels will be reported before
you launch, via the console / message box. (Well, one hopes; the machinery is all there for it, anyhow.)

Fonts are from [DaFont](http://www.DaFont.com)

Sounds are from

[GRSites](http://www.grsites.com/archive/sounds/)

or

[Media College](http://www.mediacollege.com/downloads/sound-effects/)

or

[Indie Game Designer](http://indiegamedesigner.com/)

Decent-looking art is either from Indie Game Designer or [2D Art for Game Programmers](http://2dgameartforprogrammers.blogspot.mx).
The rest consists of my own fantastic efforts with [GIMP](http://www.gimp.org/) and [GraphicsGale](http://www.humanbalance.net/gale/us/).

Image sheets made with [TexturePacker](http://www.codeandweb.com/texturepacker).