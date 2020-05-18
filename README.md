solar2d-snippets
================

Installation: git clone --recursive https://github.com/ggcrunchy/solar2d-snippets.git

Various bits and pieces. Some of these are components of a separately-developed game (often the same code, courtesy of submodules). Other things were tests that took on a life of their own. Still others were mere curiosity.

Some snippets have since graduated into programs of their own.

**HOW-TO**

After the intro, choose a sample from the listbox in the upper left corner. Many samples have a short explanation, shown in the marquee at the bottom, which I'll try to improve upon as time goes on. Hit "Launch" to start the sample.
You can leave a sample and return to the choices menu with the "Go Back" button or, depending upon the platform, the appropriate "Back" key or button.

**ABOUT**

Most of the demos right now are just automatic. In "Nodes", the boxes may be dragged around, lines may be
dragged between the nodes, and the links that result may then be broken. A few samples provide widgets that
allow for changing some setting or other. In "Timers", much of the output goes to the console, and what's
happening is probably less than obvious to someone not actually reading the code itself to see the flow (I
might just evict this one).

"Game" comprises some bits excerpted from a game in progress (well, more or less!). The "player" is the white
dot, who can be controlled in several ways: with the buttons in the bottom left; by double-tapping a spot on
the map; using the cursor keys (in the simulator or desktop builds); through your favorite input device. A
button also appears when you're over a warp or switch, in order to use those; this can be done by clicking it
or pressing the space key (other devices pending). At the moment, I've only added a maze generator to go with
the switch.

Also, you can set some debug stuff in the Options screen, from the main menu, as well as wipe any persisent
state, namely any levels you've saved in the editor.

"Editor" is likewise part of an editor for the same game. There is a lot going on, very little of it documented
(an unwelcome task, to say the least). Maybe later I'll describe how to use it. :P (It is not pretty; there is
much I would like to redesign.) If by some chance you puzzle it out, you can hit "Test" to try the level out; at
a bare minimum, a starting cell must have been assigned in the "Player" view. Erroneous levels will be reported
before you launch, via the console / message box. (Well, one hopes! The machinery is all there for it, anyhow.)

Apologies for any broken samples. Lately I've only been able to attend to this sporadically. The submodule-heavy approach also obviously introduces its own maintenance problems.

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
