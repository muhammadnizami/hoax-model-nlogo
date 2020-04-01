globals[
  initial-outbreak
]

turtles-own
[
  believer?
  nonbeliever?
  susceptible?

  hoax-buzzer?
  clarifying-buzzer?
  swing?

  become-believer-probability
  become-nonbeliever-probability
  become-susceptible-probability
]

; scope: observer
; setups the network and initial outbreak
to setup-network
  clear-all
  set-default-shape turtles "circle"
  ifelse network-type = "spatially clustered"
  [
    setup-nodes
    setup-spatially-clustered-network
  ]
  [
    ifelse network-type = "barabasi albert"
    [
      setup-barabasi-albert-network-nodes
    ]
    [
      setup-nodes
      setup-erdos-renyi-network
    ]
  ]
  ask turtles[ set size 0.5 ]
  ask n-of initial-outbreak-size turtles with [ swing? ]
  [
    become-believer
  ]
  reset-ticks
  setup-plots
end

; scope: observer
; turns some of the swing agents into buzzers
to setup-buzzers
  clear-hoax-buzzers
  clear-clarifying-buzzers
  setup-hoax-buzzers
  setup-clarifying-buzzers
  ask links [ set color white ]
end

; scope: observer
; turns every hoax buzzers into swing agents
to clear-hoax-buzzers
  ask turtles with [hoax-buzzer?]
  [
    become-swing
    become-susceptible
  ]
end

; scope: observer
; turns every clarifying buzzers into swing agents
to clear-clarifying-buzzers
  ask turtles with [clarifying-buzzer?]
  [
    become-swing
    become-susceptible
  ]
end

to reset-swing-agents
  clear-all
  set-default-shape turtles "circle"
  ifelse network-type = "spatially clustered"
  [
    setup-nodes
    setup-spatially-clustered-network
  ]
  [
    ifelse network-type = "barabasi albert"
    [
      setup-barabasi-albert-network-nodes
    ]
    [
      setup-nodes
      setup-erdos-renyi-network
    ]
  ]
  ask turtles[ set size 0.5 ]
  reset-ticks
  setup-plots
end

; scope: observer
; selects some buzzer candidate based on placement strategy and number
to-report select-buzzers [number strategy]
  ifelse strategy = "random"
  [
  report n-of number turtles with[ swing? ]
  ]
  [
    ifelse strategy = "supernodes"
    [
      report n-of number max-n-of (placement-threshold * count turtles with [swing?]) turtles with [swing?] [count link-neighbors]
    ]
    [
      report n-of number min-n-of (placement-threshold * count turtles with [swing?]) turtles with [swing?] [count link-neighbors]
    ]
  ]
end

; scope: observer
; setups clarifying buzzers
to setup-clarifying-buzzers
  ask select-buzzers number-of-clarifying-buzzers clarifying-buzzer-placement
  [
    become-clarifying-buzzer
  ]
end

; scope: observer
; setups hoax buzzers
to setup-hoax-buzzers
  ask select-buzzers number-of-hoax-buzzers hoax-buzzer-placement
  [
    become-hoax-buzzer
  ]
end

; scope: observer
; creates initial nodes for spatially clustered network
to setup-nodes

  create-turtles number-of-nodes
  [
    ; for visual reasons, we don't put any nodes *too* close to the edges
    setxy (random-xcor * 0.95) (random-ycor * 0.95)
    become-swing
    become-susceptible
  ]
end

; scope: observer
; creates links for spatially clustered network
to setup-spatially-clustered-network
  let num-links (k * number-of-nodes) / 2
  while [count links < num-links ]
  [
    ask one-of turtles
    [
      let choice (min-one-of (other turtles with [not link-neighbor? myself])
                   [distance myself])
      if choice != nobody [ create-link-with choice ]
    ]
  ]
end

; scope: observer
; creates nodes and links for erdos-renyi network
to setup-erdos-renyi-network
  let prob-link ( k ) / ( number-of-nodes - 1 ) / 2
  ask turtles [
    let cur-turtle self
    ask other turtles [
      if random-float 1 < prob-link [ create-link-with cur-turtle ]
    ]
  ]
end

; scope: observer
; creates nodes and links for barabasi-albert network
to setup-barabasi-albert-network-nodes
  let m round (k / 1.95)
  ; initial m connected nodes
  create-turtles m
  [
    ; for visual reasons, we don't put any nodes *too* close to the edges
    setxy (random-xcor * 0.95) (random-ycor * 0.95)
    become-swing
    become-susceptible
  ]

  ; connect the initial nodes with a new node
  create-turtles 1
  [
    become-swing
    become-susceptible
    let current-turtle self
    ask other turtles[
      create-link-with current-turtle
    ]
  ]

  repeat number-of-nodes - m - 1[
    create-turtles 1
    [
      ; for visual reasons, we don't put any nodes *too* close to the edges
      setxy (random-xcor * 0.95) (random-ycor * 0.95)
      become-swing
      become-susceptible

      let current-turtle self
      repeat m [
        ask [one-of both-ends] of one-of links with [not member? current-turtle both-ends]
        [
          create-link-with current-turtle
        ]
      ]
    ]
  ]
end

;scope: observer
; layouts the network for pretty viewer
to layout
  ;; the number 3 here is arbitrary; more repetitions slows down the
  ;; model, but too few gives poor layouts
  repeat 3 [
    ;; the more turtles we have to fit into the same amount of space,
    ;; the smaller the inputs to layout-spring we'll need to use
    let factor sqrt count turtles
    ;; numbers here are arbitrarily chosen for pleasing appearance
    layout-spring turtles links (1 / factor) (7 / factor) (1 / factor)
    display  ;; for smooth animation
  ]
  ;; don't bump the edges of the world
  let x-offset max [xcor] of turtles + min [xcor] of turtles
  let y-offset max [ycor] of turtles + min [ycor] of turtles
  ;; big jumps look funny, so only adjust a little each time
  set x-offset limit-magnitude x-offset 0.1
  set y-offset limit-magnitude y-offset 0.1
  ask turtles [ setxy (xcor - x-offset / 2) (ycor - y-offset / 2) ]
end

; helper for layout function
to-report limit-magnitude [number limit]
  if number > limit [ report limit ]
  if number < (- limit) [ report (- limit) ]
  report number
end

; scope: observer
; executes instructions for one tick
to go
  ;checks stop condition
  if stop-when-hoax-died?
  [
    if count turtles with [ swing? and believer? ] <= count turtles with [ swing? ] * hoax-die-threshold
    [ stop ]
  ]
  if ticks >= stop-at
    [ stop ]

  ; the probabilities are calculated before the transition
  ask turtles with [ swing? ]
    [ update-probabilities ]

  ; executes state transition for all turtles
  ask turtles with [ swing? ]
    [ execute-probabilities ]
  tick
end

to become-hoax-buzzer  ;; turtle procedure
  set hoax-buzzer? true
  set clarifying-buzzer? false
  set swing? false
  become-believer

  set shape "target"
end

to become-clarifying-buzzer  ;; turtle procedure
  set hoax-buzzer? false
  set clarifying-buzzer? true
  set swing? false
  become-nonbeliever

  set shape "target"
end

to become-swing  ;; turtle procedure
  set hoax-buzzer? false
  set clarifying-buzzer? false
  set swing? true

  set shape "circle"
end

to become-believer  ;; turtle procedure
  set believer? true
  set nonbeliever? false
  set susceptible? false
  set color red
end

to become-susceptible  ;; turtle procedure
  set believer? false
  set nonbeliever? false
  set susceptible? true
  set color gray
end

to become-nonbeliever  ;; turtle procedure
  set believer? false
  set nonbeliever? true
  set susceptible? false
  set color blue
end

; scope: turtle
; calculates the state transition probabilities
to update-probabilities
  set become-believer-probability ifelse-value (swing?) [ ifelse-value(susceptible?)[f][0] + ifelse-value(believer?)[1 - j - h][0]][0]
  set become-nonbeliever-probability ifelse-value (swing?) [ifelse-value(susceptible?)[g][0] + ifelse-value(believer?)[h][0] + ifelse-value(nonbeliever?)[1 - forget-chance][0]][0]
  set become-susceptible-probability ifelse-value (swing?) [ifelse-value(believer?)[j][0] + ifelse-value(nonbeliever?)[forget-chance][0] + ifelse-value(susceptible?)[1 - f - g][0]][0]
end

; scope: turtle
; executes turtle state transition multinomial probability
to execute-probabilities
  let r random-float 1
  ifelse r < become-believer-probability
    [ become-believer ]
  [ ifelse r - become-believer-probability < become-nonbeliever-probability
    [ become-nonbeliever ]
    [ become-susceptible ]
  ]
end

; scope: turtle
; the transition functions
; please refer to the paper for more details
to-report f[]
  let nB count link-neighbors with [believer?]
  let nN count link-neighbors with [nonbeliever?]
  ifelse nB * (1 + hoax-believability) = 0 ;avoid division by zero
  [report 0]
  [report spread-chance * (nB * (1 + hoax-believability))/(nB * (1 + hoax-believability) + nN * (1 - hoax-believability))]
end

; scope: turtle
; the transition functions
; please refer to the paper for more details
to-report g[]
  let nB count link-neighbors with [believer?]
  let nN count link-neighbors with [nonbeliever?]
  ifelse nN * (1 - hoax-believability) = 0;avoid division by zero
  [report 0]
  [report spread-chance * (nN * (1 - hoax-believability))/(nB * (1 + hoax-believability) + nN * (1 - hoax-believability))]
end

; scope: turtle
; the transition functions
; please refer to the paper for more details
to-report h[]
  let nB count link-neighbors with [believer?]
  let nN count link-neighbors with [nonbeliever?]
  ifelse nN * induced-verification-chance = 0;avoid division by zero
  [report voluntary-verification-chance]
  [report (1 - voluntary-verification-chance) * spread-chance * (nN * induced-verification-chance)/(nB * (1 - induced-verification-chance - backfire-chance) + nN * (induced-verification-chance + backfire-chance)) + voluntary-verification-chance]
end

; scope: turtle
; the transition functions
; please refer to the paper for more details
to-report j[]
  let nB count link-neighbors with [believer?]
  let nN count link-neighbors with [nonbeliever?]
  ifelse nN * (induced-verification-chance + backfire-chance) = 0;avoid division by zero
  [report forget-chance ]
  [report forget-chance * (1 - spread-chance * (nN * (induced-verification-chance + backfire-chance)/(nB * (1 - induced-verification-chance - backfire-chance) + nN * (induced-verification-chance + backfire-chance))))]
end

; scope: turtle
; binomial version of the functions
; isn't used anymore
to-report h-old[]
  let nN count link-neighbors with [nonbeliever?]
  report (1 - (1 - induced-verification-chance) ^ nN) * ( 1 - voluntary-verification-chance ) + voluntary-verification-chance
end

; scope: turtle
; binomial version of the functions
; isn't used anymore
to-report j-old[]
  report (1 - h) * forget-chance
end
@#$#@#$#@
GRAPHICS-WINDOW
322
26
781
486
-1
-1
11.0
1
10
1
1
1
0
0
0
1
-20
20
-20
20
1
1
1
ticks
30.0

SLIDER
880
70
1085
103
spread-chance
spread-chance
0.0
1
0.5
0.01
1
NIL
HORIZONTAL

BUTTON
25
380
156
420
NIL
setup-buzzers
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
882
26
977
66
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
883
320
1138
484
Network Status
time
% of swing nodes
0.0
52.0
0.0
100.0
true
true
"" ""
PENS
"nonbeliever" 1.0 0 -13345367 true "" "plot (count turtles with [swing? and nonbeliever?]) / (count turtles with [swing?]) * 100"
"believer" 1.0 0 -2674135 true "" "plot (count turtles with [swing? and believer?]) / (count turtles with [swing?]) * 100"
"susceptible" 1.0 0 -7500403 true "" "plot (count turtles with [swing? and susceptible?]) / (count turtles with [swing?]) * 100"

SLIDER
25
15
230
48
number-of-nodes
number-of-nodes
10
10000
10000.0
5
1
NIL
HORIZONTAL

SLIDER
21
190
226
223
initial-outbreak-size
initial-outbreak-size
0
number-of-nodes
6.0
1
1
NIL
HORIZONTAL

SLIDER
25
50
230
83
k
k
1
min list (number-of-nodes - 1) 20
6.0
1
1
NIL
HORIZONTAL

SLIDER
878
108
1085
141
hoax-believability
hoax-believability
0
1
0.6
0.01
1
NIL
HORIZONTAL

SLIDER
876
147
1086
180
induced-verification-chance
induced-verification-chance
0
1
0.06
0.01
1
NIL
HORIZONTAL

SLIDER
877
232
1087
265
voluntary-verification-chance
voluntary-verification-chance
0
1
0.02
0.01
1
NIL
HORIZONTAL

SLIDER
876
273
1087
306
forget-chance
forget-chance
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
21
268
225
301
number-of-clarifying-buzzers
number-of-clarifying-buzzers
0
(number-of-nodes - number-of-hoax-buzzers - 1) * placement-threshold
0.0
1
1
NIL
HORIZONTAL

SLIDER
21
228
225
261
number-of-hoax-buzzers
number-of-hoax-buzzers
0
number-of-nodes - 1
0.0
1
1
NIL
HORIZONTAL

CHOOSER
25
87
205
132
network-type
network-type
"spatially clustered" "barabasi albert" "erdos renyi"
1

SLIDER
876
192
1085
225
backfire-chance
backfire-chance
0
1 - induced-verification-chance
0.08
0.01
1
NIL
HORIZONTAL

CHOOSER
23
299
206
344
clarifying-buzzer-placement
clarifying-buzzer-placement
"random" "supernodes" "least neighbor nodes"
1

INPUTBOX
986
10
1054
70
stop-at
500.0
1
0
Number

SWITCH
1056
28
1269
61
stop-when-hoax-died?
stop-when-hoax-died?
1
1
-1000

BUTTON
23
145
158
178
NIL
setup-network
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
27
427
191
460
NIL
clear-hoax-buzzers
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
31
466
224
499
NIL
clear-clarifying-buzzers
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
27
502
225
535
NIL
setup-clarifying-buzzers
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
168
146
243
179
NIL
layout
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
20
342
212
375
placement-threshold
placement-threshold
0
1
0.05
0.001
1
NIL
HORIZONTAL

SLIDER
1152
72
1344
105
hoax-die-threshold
hoax-die-threshold
0
0.02
0.0
0.0005
1
NIL
HORIZONTAL

CHOOSER
210
299
316
344
hoax-buzzer-placement
hoax-buzzer-placement
"random" "supernodes" "least neighbor nodes"
1

@#$#@#$#@
## WHAT IS IT?

This model demonstrates the spread of a virus through a network.  Although the model is somewhat abstract, one interpretation is that each node represents a computer, and we are modeling the progress of a computer virus (or worm) through this network.  Each node may be in one of three states:  susceptible, infected, or resistant.  In the academic literature such a model is sometimes referred to as an SIR model for epidemics.

## HOW IT WORKS

Each time step (tick), each infected node (colored red) attempts to infect all of its neighbors.  Susceptible neighbors (colored green) will be infected with a probability given by the VIRUS-SPREAD-CHANCE slider.  This might correspond to the probability that someone on the susceptible system actually executes the infected email attachment.
Resistant nodes (colored gray) cannot be infected.  This might correspond to up-to-date antivirus software and security patches that make a computer immune to this particular virus.

Infected nodes are not immediately aware that they are infected.  Only every so often (determined by the VIRUS-CHECK-FREQUENCY slider) do the nodes check whether they are infected by a virus.  This might correspond to a regularly scheduled virus-scan procedure, or simply a human noticing something fishy about how the computer is behaving.  When the virus has been detected, there is a probability that the virus will be removed (determined by the RECOVERY-CHANCE slider).

If a node does recover, there is some probability that it will become resistant to this virus in the future (given by the GAIN-RESISTANCE-CHANCE slider).

When a node becomes resistant, the links between it and its neighbors are darkened, since they are no longer possible vectors for spreading the virus.

## HOW TO USE IT

Using the sliders, choose the NUMBER-OF-NODES and the AVERAGE-NODE-DEGREE (average number of links coming out of each node).

The network that is created is based on proximity (Euclidean distance) between nodes.  A node is randomly chosen and connected to the nearest node that it is not already connected to.  This process is repeated until the network has the correct number of links to give the specified average node degree.

The INITIAL-OUTBREAK-SIZE slider determines how many of the nodes will start the simulation infected with the virus.

Then press SETUP to create the network.  Press GO to run the model.  The model will stop running once the virus has completely died out.

The VIRUS-SPREAD-CHANCE, VIRUS-CHECK-FREQUENCY, RECOVERY-CHANCE, and GAIN-RESISTANCE-CHANCE sliders (discussed in "How it Works" above) can be adjusted before pressing GO, or while the model is running.

The NETWORK STATUS plot shows the number of nodes in each state (S, I, R) over time.

## THINGS TO NOTICE

At the end of the run, after the virus has died out, some nodes are still susceptible, while others have become immune.  What is the ratio of the number of immune nodes to the number of susceptible nodes?  How is this affected by changing the AVERAGE-NODE-DEGREE of the network?

## THINGS TO TRY

Set GAIN-RESISTANCE-CHANCE to 0%.  Under what conditions will the virus still die out?   How long does it take?  What conditions are required for the virus to live?  If the RECOVERY-CHANCE is bigger than 0, even if the VIRUS-SPREAD-CHANCE is high, do you think that if you could run the model forever, the virus could stay alive?

## EXTENDING THE MODEL

The real computer networks on which viruses spread are generally not based on spatial proximity, like the networks found in this model.  Real computer networks are more often found to exhibit a "scale-free" link-degree distribution, somewhat similar to networks created using the Preferential Attachment model.  Try experimenting with various alternative network structures, and see how the behavior of the virus differs.

Suppose the virus is spreading by emailing itself out to everyone in the computer's address book.  Since being in someone's address book is not a symmetric relationship, change this model to use directed links instead of undirected links.

Can you model multiple viruses at the same time?  How would they interact?  Sometimes if a computer has a piece of malware installed, it is more vulnerable to being infected by more malware.

Try making a model similar to this one, but where the virus has the ability to mutate itself.  Such self-modifying viruses are a considerable threat to computer security, since traditional methods of virus signature identification may not work against them.  In your model, nodes that become immune may be reinfected if the virus has mutated to become significantly different than the variant that originally infected the node.

## RELATED MODELS

Virus, Disease, Preferential Attachment, Diffusion on a Directed Network

## NETLOGO FEATURES

Links are used for modeling the network.  The `layout-spring` primitive is used to position the nodes and links such that the structure of the network is visually clear.

Though it is not used in this model, there exists a network extension for NetLogo that you can download at: https://github.com/NetLogo/NW-Extension.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Stonedahl, F. and Wilensky, U. (2008).  NetLogo Virus on a Network model.  http://ccl.northwestern.edu/netlogo/models/VirusonaNetwork.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2008 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2008 Cite: Stonedahl, F. -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment 1.1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup-network
setup-buzzers</setup>
    <go>go</go>
    <metric>count turtles with [ swing? and nonbeliever? ]</metric>
    <metric>count turtles with [ swing? and believer? ]</metric>
    <metric>count turtles with [ swing? and susceptible? ]</metric>
    <enumeratedValueSet variable="stop-when-hoax-died?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spread-chance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;barabasi albert&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hoax-believability">
      <value value="0.3"/>
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clarifying-buzzer-placement">
      <value value="&quot;random&quot;"/>
      <value value="&quot;supernodes&quot;"/>
      <value value="&quot;least neighbor nodes&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forget-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="induced-verification-chance">
      <value value="0"/>
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="backfire-chance">
      <value value="0"/>
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="placement-threshold">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voluntary-verification-chance">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-hoax-buzzers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-clarifying-buzzers">
      <value value="0"/>
      <value value="5"/>
      <value value="25"/>
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment 0" repetitions="3" runMetricsEveryStep="true">
    <setup>setup-network
setup-buzzers</setup>
    <go>go</go>
    <metric>count turtles with [ swing? and nonbeliever? ]</metric>
    <metric>count turtles with [ swing? and believer? ]</metric>
    <metric>count turtles with [ swing? and susceptible? ]</metric>
    <enumeratedValueSet variable="stop-when-hoax-died?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hoax-die-threshold">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="induced-verification-chance">
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="10"/>
      <value value="100"/>
      <value value="1000"/>
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spread-chance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;barabasi albert&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hoax-believability">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clarifying-buzzer-placement">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forget-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="backfire-chance">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="placement-threshold">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voluntary-verification-chance">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-hoax-buzzers">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-clarifying-buzzers">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment 1.2" repetitions="1" runMetricsEveryStep="true">
    <setup>setup-network
setup-buzzers</setup>
    <go>go</go>
    <metric>count turtles with [ swing? and nonbeliever? ]</metric>
    <metric>count turtles with [ swing? and believer? ]</metric>
    <metric>count turtles with [ swing? and susceptible? ]</metric>
    <enumeratedValueSet variable="stop-when-hoax-died?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spread-chance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;barabasi albert&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hoax-believability">
      <value value="0.3"/>
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clarifying-buzzer-placement">
      <value value="&quot;supernodes&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forget-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="induced-verification-chance">
      <value value="0"/>
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="backfire-chance">
      <value value="0"/>
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="placement-threshold">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voluntary-verification-chance">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-hoax-buzzers">
      <value value="5"/>
      <value value="25"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-clarifying-buzzers">
      <value value="5"/>
      <value value="25"/>
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment 1.3" repetitions="1" runMetricsEveryStep="false">
    <setup>setup-network
setup-buzzers</setup>
    <go>go</go>
    <metric>count turtles with [ swing? and nonbeliever? ]</metric>
    <metric>count turtles with [ swing? and believer? ]</metric>
    <metric>count turtles with [ swing? and susceptible? ]</metric>
    <enumeratedValueSet variable="stop-when-hoax-died?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spread-chance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;barabasi albert&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hoax-believability">
      <value value="0.3"/>
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clarifying-buzzer-placement">
      <value value="&quot;random&quot;"/>
      <value value="&quot;supernodes&quot;"/>
      <value value="&quot;least neighbor nodes&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forget-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="induced-verification-chance">
      <value value="0"/>
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="backfire-chance">
      <value value="0"/>
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="placement-threshold">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voluntary-verification-chance">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-hoax-buzzers">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-of-clarifying-buzzers" first="0" step="5" last="101"/>
  </experiment>
  <experiment name="experiment 1.4" repetitions="1" runMetricsEveryStep="false">
    <setup>setup-network
setup-buzzers</setup>
    <go>go</go>
    <metric>count turtles with [ swing? and nonbeliever? ]</metric>
    <metric>count turtles with [ swing? and believer? ]</metric>
    <metric>count turtles with [ swing? and susceptible? ]</metric>
    <enumeratedValueSet variable="stop-when-hoax-died?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spread-chance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;barabasi albert&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hoax-believability">
      <value value="0.3"/>
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clarifying-buzzer-placement">
      <value value="&quot;supernodes&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forget-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="induced-verification-chance">
      <value value="0"/>
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="backfire-chance">
      <value value="0"/>
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="placement-threshold">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voluntary-verification-chance">
      <value value="0.02"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-of-hoax-buzzers" first="0" step="17" last="101"/>
    <steppedValueSet variable="number-of-clarifying-buzzers" first="0" step="17" last="101"/>
  </experiment>
  <experiment name="experiment 1.5" repetitions="1" runMetricsEveryStep="true">
    <setup>setup-network
setup-buzzers</setup>
    <go>go</go>
    <metric>count turtles with [ swing? and nonbeliever? ]</metric>
    <metric>count turtles with [ swing? and believer? ]</metric>
    <metric>count turtles with [ swing? and susceptible? ]</metric>
    <enumeratedValueSet variable="stop-when-hoax-died?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spread-chance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;barabasi albert&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hoax-believability">
      <value value="0.3"/>
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hoax-buzzer-placement">
      <value value="&quot;random&quot;"/>
      <value value="&quot;supernodes&quot;"/>
      <value value="&quot;least neighbor nodes&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clarifying-buzzer-placement">
      <value value="&quot;random&quot;"/>
      <value value="&quot;supernodes&quot;"/>
      <value value="&quot;least neighbor nodes&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forget-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="induced-verification-chance">
      <value value="0"/>
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="backfire-chance">
      <value value="0"/>
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="placement-threshold">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voluntary-verification-chance">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-hoax-buzzers">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-clarifying-buzzers">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment 1.6" repetitions="1" runMetricsEveryStep="true">
    <setup>setup-network
setup-buzzers</setup>
    <go>go</go>
    <metric>count turtles with [ swing? and nonbeliever? ]</metric>
    <metric>count turtles with [ swing? and believer? ]</metric>
    <metric>count turtles with [ swing? and susceptible? ]</metric>
    <enumeratedValueSet variable="stop-when-hoax-died?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stop-at">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spread-chance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;barabasi albert&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hoax-believability">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hoax-buzzer-placement">
      <value value="&quot;random&quot;"/>
      <value value="&quot;supernodes&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clarifying-buzzer-placement">
      <value value="&quot;random&quot;"/>
      <value value="&quot;supernodes&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forget-chance">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="induced-verification-chance">
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="backfire-chance">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="placement-threshold">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-outbreak-size">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="k">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voluntary-verification-chance">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-hoax-buzzers">
      <value value="5"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-clarifying-buzzers">
      <value value="5"/>
      <value value="25"/>
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
