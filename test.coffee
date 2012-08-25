@[k] = v for k,v of phys

canvas = document.getElementById('stage')
c = canvas.getContext('2d')

stats = new Stats(); statsEl = stats.domElement
document.getElementById('stage-frame').appendChild(statsEl)


drawPoly = (poly) ->
  vs = poly.verts; v1 = vs[0]
  c.beginPath()
  c.moveTo(v1.x, v1.y)
  c.lineTo(v.x, v.y) for v in vs
  c.closePath()
  c.fill()
drawCircle = (circle) ->
  c.beginPath()
  c.arc(circle.center.x, circle.center.y, circle.radius, 0,Math.PI*2)
  c.closePath()
  c.fill()
drawContact = (ct) ->
  c.beginPath()
  c.arc(ct.p.x, ct.p.y, 2.5, 0,Math.PI*2)
  c.closePath()
  c.fill()
drawSpace = (space) ->
  c.fillStyle = '#333'
  for body in space.bodies then for s in body.transform
    switch
      when s.verts then drawPoly s
      when s.radius then drawCircle s
  c.fillStyle = '#393'
  for _,ct of space.cts when ct.t == space.t
    drawContact ct


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

t = 1/120


setInterval(
  ->
    stats.begin()
    space.update t, 3
    stats.end()

    c.clearRect 0,0, canvas.width,canvas.height
    drawSpace space
    if dragging
      b = dragging
      tgt = mouseLast.cp().add(draggingOffset)
      b.vel.addMult(tgt.sub(b.pos), .4 / t).mult(.5)
  1000*t
)

dragging = null
mouseLast = Vec(0,0)
mouseDelta = Vec(0,0)
draggingOffset = null

canvas.onmousemove = (e) ->
  cur = Vec(e.layerX || e.offsetX, e.layerY || e.offsetY)
  mouseLast.set(cur)
canvas.onmousedown = (e) ->
  e.preventDefault()
  dragging = space.find(mouseLast)[0]
  draggingOffset = dragging.pos.cp().sub(mouseLast)
canvas.onmouseup = ->
  dragging = null
