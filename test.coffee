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
  c.clearRect 0,0, canvas.width,canvas.height
  c.fillStyle = '#333'
  for body in space.bodies then for s in body.transform
    switch
      when s.verts then drawPoly s
      when s.radius then drawCircle s
  c.fillStyle = '#595'
  for _,ct of space.cts when ct.t == space.t
    drawContact ct


shapes = [
  [Box(25,25)]
  [Circle(15)]
  [Box(3/8*30,30), Box(30,3/8*30)]
]
bodies = []
for _ in [0..150]
  pos = Vec(150+400*Math.random(), 400*Math.random())
  i = Math.floor(3*Math.random())
  bodies.push Body(pos, shapes[i])
bodies.push(
  Body(Vec(650/2,450),  [Box(420,30)], Infinity, 0)
  Body(Vec(650-80,400), [Box(150,30)], Infinity, -.8)
  Body(Vec(    80,400), [Box(150,30)], Infinity, .8)
)

space = Space(bodies)


t = 1/120
setInterval(
  ->
    stats.begin()
    space.update t, 3
    stats.end()
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
  if dragging
    draggingOffset = dragging.pos.cp().sub(mouseLast)
canvas.onmouseup = ->
  dragging = null

reqFrame = window.mozRequestAnimationFrame || window.webkitRequestAnimationFrame
drawT = 0
run = ->
  reqFrame run
  if space.t != drawT
    drawT = space.t
    drawSpace space
reqFrame run
