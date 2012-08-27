#phys.coffee

Rigid body physics engine written using Coffeescript.

#Example

```coffeescript
bodies = []

for _ in [0..80]
  pos = Vec(150+300*Math.random(), 200*Math.random())
  shape = if Math.random()>.5 then Box(30,30) else Circle(18)
  bodies.push Body(pos, [shape])

bodies.push(
  Body(Vec(300,450), [Box(400,30)], Infinity, 0)
  Body(Vec(600-80,400), [Box(150,30)], Infinity, -1)
  Body(Vec(    80,400), [Box(150,30)], Infinity, 1)
)

space = Space(bodies)

step = 1/120; iterations = 5

space.update step, iterations
```
