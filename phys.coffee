
Vec = (x,y) ->
  { x, y, __proto__: Vec.methods }

Vec.methods =
  cp: -> { @x, @y, @__proto__ }
  set: ({@x,@y}) -> @
  set_: (@x,@y) -> @
  opp: -> @x = -@x; @y = -@y; @
  mult: (s) -> @x *= s; @y *= s; @
  add: ({x,y}) -> @x += x; @y += y; @
  addMult: ({x,y},s) -> @x += s*x; @y += s*y; @
  sub: ({x,y}) -> @x -= x; @y -= y; @
  subMult: ({x,y},s) -> @x -= x*s; @y -= y*s; @
  dot: ({x,y}) -> @x*x + @y*y
  cross: ({x,y}) -> -(@x * -y + @y * x)
  perp: -> y = @y; @y = @x; @x = -y; @
  len: -> Math.sqrt(@dot(@))
  unit: -> l = @len(); @x /= l; @y /= l; @
  rotate: ({x,y}) -> x_ = @x*x - @y*y; y_ = @y*x + @x*y; @x = x_; @y = y_; @
  rotate_: (x,y) -> x_ = @x*x - @y*y; y_ = @y*x + @x*y; @x = x_; @y = y_; @
  toString: -> "{#{@x},#{@y}}"

Vec.polar = (a) -> Vec(Math.cos(a), Math.sin(a))

Axis = (n,d) ->
  { n, d, __proto__: Axis.methods }

Axis.methods =
  cp: -> { n: @n.cp(); d: @d; __proto__: Axis.methods }
  opp: -> @n.opp(); @
  toString: -> "Axis(#{@n},#{@d})"


Circle = (radius) -> {
  radius
  area: radius*radius * Math.PI
  inertia: radius*radius / 2
  obj: -> { center: null, radius, bounds: { p1: Vec(), p2: Vec() } }
  update: (obj,pos,dir) ->
    obj.center = pos
    ext = Vec(@radius,@radius)
    obj.bounds.p1.set(pos).sub(ext)
    obj.bounds.p2.set(pos).add(ext)
}


Poly = (verts) -> {
  verts: verts
  axes:
    Poly.sides(verts).map ([v1,v2]) ->
      n = v2.cp().sub(v1).unit().perp()
      Axis(n, n.dot(v1))
  area:
    (s = 0
    for [v1,v2,v3] in Poly.sides3(verts)
      s += v2.x * (v1.y-v3.y)
    s / 2)
  inertia:
    (a = 0; b = 0
    for [v1,v2] in Poly.sides(verts)
      ai = v2.cross(v1)
      bi = v1.dot(v1) + v2.dot(v2) + v1.dot(v2)
      a += ai * bi; b += bi
    a / (6 * b) )
  obj: -> {
    verts: @verts.map(-> Vec())
    axes: @axes.map(-> Axis(Vec()))
    bounds: { p1: Vec(), p2: Vec() }
  }
  update: (obj,pos,dir) ->
    vtmp = Vec()
    @verts.forEach (v,i) ->
      v2 = obj.verts[i]
      v2.set(pos).add(vtmp.set(dir).rotate(v))
    @axes.forEach (a,i) ->
      a2 = obj.axes[i]
      a2.n.set(a.n).rotate(dir)
      a2.d = a2.n.dot(pos) + a.d
    l = Infinity; r = -Infinity
    t = Infinity; b = -Infinity
    for v in obj.verts
      l = Math.min(l,v.x); r = Math.max(r,v.x)
      t = Math.min(t,v.y); b = Math.max(b,v.y)
    obj.bounds.p1.set_(l,t)
    obj.bounds.p2.set_(r,b)
}

Poly.sides = (xs) ->
  xs.map (x,i) -> [x, xs[(i+1) % xs.length]]
Poly.sides3 = (xs) ->
  xs.map (x,i) -> [x, xs[(i+1) % xs.length], xs[(i+2) % xs.length]]

Box = (w,h) ->
  Poly([Vec(-w/2,-h/2), Vec(-w/2, h/2), Vec(w/2, h/2), Vec(w/2, -h/2)])


Body = (pos,shapes,density=1,ang=0,bounce=.2) ->
  area = 0; inertia = 0
  for s in shapes
    area += s.area
    inertia += s.inertia
  mass = area * density
  inertia = mass * inertia

  {
    id: Body.tag++
    pos, ang
    vel: Vec(0,0), rot: 0
    snap: Vec(0,0), asnap: 0

    shapes
    transform: s.obj() for s in shapes

    density, bounce
    mass, inertia
    invMass: 1 / mass
    invInertia: 1 / inertia

    __proto__: Body.methods
  }

Body.tag = 0

Body.methods =
  update: (gravity, dt) ->
    @pos.addMult(@vel, dt).add(@snap)
    @ang += @rot*dt + @asnap
    @snap.set_(0,0)
    @asnap = 0
    unless @mass is Infinity
      @vel.addMult(gravity, dt)
    dir = Vec.polar(@ang)
    for obj,i in @transform
      @shapes[i].update obj, @pos, dir
  applySnap: (j, rn) ->
    @snap.addMult(j, @invMass)
    @asnap += j.dot(rn) * @invInertia
  applySnapOpp: (j, rn) ->
    @snap.subMult(j, @invMass)
    @asnap -= j.dot(rn) * @invInertia
  applyVel: (j, rn) ->
    @vel.addMult(j, @invMass)
    @rot += j.dot(rn) * @invInertia
  applyVelOpp: (j, rn) ->
    @vel.subMult(j, @invMass)
    @rot -= j.dot(rn) * @invInertia


Collision =
  sepAxisPP: (poly1,poly2) ->
    maxd = -Infinity; maxn = null
    for a in poly1.axes
      d = Infinity
      d = Math.min(d, v.dot(a.n)) for v in poly2.verts
      d = d - a.d
      if d > maxd
        maxd = d; maxn = a.n
    return false if maxd >= 0
    Axis(maxn, maxd)

  containsV: (poly, v) ->
    for a in poly.axes
      if a.n.dot(v) > a.d
        return false
    true

  findVs: (poly1, poly2) ->
    pts = []
    pts.push {p: v, id: i} for v,i in poly1.verts when Collision.containsV(poly2, v)
    pts.push {p: v, id: 8|i} for v,i in poly2.verts when Collision.containsV(poly1, v)
    pts

  polyPoly: (p1, p2) ->
    a1 = Collision.sepAxisPP(p1, p2)
    a2 = Collision.sepAxisPP(p2, p1)
    if a1 and a2
      n = if a1.d > a2.d then a1.n else a2.n.cp().opp()
      d = Math.max(a1.d, a2.d)
      { n, dist: d, pts: Collision.findVs p1, p2 }
    else false

  circleCircle: (c1, c2) ->
    r = c2.center.cp().sub(c1.center)
    min = c1.radius + c2.radius
    return false if r.dot(r) > min*min
    len = r.len()
    p = c1.center.cp().addMult(r, 0.5 + (c1.radius - 0.5*min)/len)
    r.mult(1/len)
    n: r, dist: len - min
    pts: [ p: p, id: 0 ]

  sepAxisPC: (p,c) ->
    max = -Infinity; maxi = 0
    for a,i in p.axes
      d = a.n.dot(c.center) - a.d - c.radius
      if d > max
        max = d; maxi = i
    if max < 0 then [max,maxi] else false

  polyCircle: (p,c) ->
    if sep = Collision.sepAxisPC(p,c)
      [max,i] = sep
      v1 = p.verts[i]; v2 = p.verts[(i+1) % p.verts.length]
      a = p.axes[i]
      d = a.n.cross(c.center)
      corner = (v) -> Collision.circleCircle({center: v, radius: 0}, c)
      switch
        when d > a.n.cross(v1) then corner v1
        when d < a.n.cross(v2) then corner v2
        else {
          n: a.n, dist: max
          pts: [ p: c.center.cp().subMult(a.n, c.radius + max/2), id: i ]
        }

  check: (a,b) ->
    switch
      when a.verts and b.verts then Collision.polyPoly(a,b)
      when a.verts and b.radius then Collision.polyCircle(a,b)
      when a.radius and b.verts
        c = Collision.polyCircle(b,a); if c then c.n = c.n.cp().opp(); c
      when a.radius and b.radius then Collision.circleCircle(a,b)


Contact = (a,b) -> {
  a, b
  n: Vec(), n2: Vec(), p: Vec(), t: 0
  jN: 0, jT: 0, massN: 0, massT: 0, snapDist: 0, bounceTgt: 0
  r1: Vec(), r2: Vec(), r1n: Vec(), r2n: Vec(), vobj: Vec()
  __proto__: Contact.methods
}

Contact.methods =
  update: (dist,n, p, @t) ->
    @n.set(n); @p.set(p); @n2.set(n).perp()
    @r1.set(p).sub(@a.pos); @r1n.set(@r1).perp()
    @r2.set(p).sub(@b.pos); @r2n.set(@r2).perp()

    @massN = @kin(@n); @massT = @kin(@n2)

    @snapDist = 0.2 * -Math.min(0, dist + 0.1)
    v = @rel @b.vel, @b.rot, @a.vel, @a.rot
    @bounceTgt = Math.max(@a.bounce, @b.bounce) * -v.dot(@n) - @jN
    @bounceTgt = Math.max(@bounceTgt, 0)

  kin: (n) ->
    1 / ( @a.invMass + @b.invMass +
      @a.invInertia * Math.pow(@r1.cross(n),2) +
      @b.invInertia * Math.pow(@r2.cross(n),2) )

  applySnap: (j) -> @a.applySnapOpp(j, @r1n); @b.applySnap(j, @r2n)
  applyVel: (j) -> @a.applyVelOpp(j, @r1n); @b.applyVel(j, @r2n)

  rel: (bv,br, av,ar) ->
    @vobj.set(bv).addMult(@r2n, br).sub(av).subMult(@r1n, ar)

  accumulated: ->
    @applyVel @vobj.set(@n).rotate_(@jN,@jT)

  correction: ->
    s = @rel @b.snap, @b.asnap, @a.snap, @a.asnap

    snapN = @massN * (@snapDist - s.dot(@n))
    @applySnap @vobj.set(@n).mult(snapN) if snapN > 0

    v = @rel @b.vel, @b.rot, @a.vel, @a.rot

    jN = @massN * -v.dot(@n)
    newN = Math.max(0, @jN + jN)

    @applyVel @vobj.set(@n).mult(newN - @jN)
    @jN = newN

  interaction: ->
    v = @rel @b.vel, @b.rot, @a.vel, @a.rot

    jN = @massN * (-v.dot(@n) + @bounceTgt)
    jT = @massT * -v.dot(@n2)

    newN = Math.max(0, @jN + jN)
    limitT = newN * 0.8
    newT = Math.min(limitT, Math.max(-limitT, @jT + jT))

    @applyVel @vobj.set(@n).rotate_(newN - @jN, newT - @jT)

    @jN = newN; @jT = newT

  perform: ->
    s = @rel @b.snap, @b.asnap, @a.snap, @a.asnap

    snapN = @massN * (@snapDist - s.dot(@n))
    @applySnap @vobj.set(@n).mult(snapN) if snapN > 0

    v = @rel @b.vel, @b.rot, @a.vel, @a.rot

    jN = @massN * (-v.dot(@n) + @bounceTgt)
    jT = @massT * -v.dot(@n2)

    newN = Math.max(0, @jN + jN)
    limitT = newN * 0.8
    newT = Math.min(limitT, Math.max(-limitT, @jT + jT))

    @applyVel @vobj.set(@n).rotate_(newN - @jN, newT - @jT)

    @jN = newN; @jT = newT


Space = (bodies) ->
  index = new SpaceIndex()
  for body in bodies then for obj in body.transform
    index.add body, obj
  {
    bodies
    gravity: Vec(0,200)
    t: 0, cts: {}, index
    __proto__: Space.methods
  }

Space.methods =
  update: (dt, iters) ->
    @t++

    for body in @bodies
      body.update(@gravity, dt)

    @index.scan (a,sa,saix, b,sb,sbix) =>
      return if a == b
      return if a.mass is Infinity && b.mass is Infinity
      if col = Collision.check(sa, sb)
        @addCt(a,b, saix,sbix, col)

    curCts = []

    for id,ct of @cts
      if ct.t+3 <= @t
        delete @cts[id]
      else
        curCts.push ct

    for ct in curCts
      ct.accumulated()
    for _ in [1..iters]
      for id,ct of curCts
        ct.correction()
    for _ in [1..iters]
      for id,ct of curCts
        ct.interaction()

  addCt: (a,b, ia,ib, col) ->
    hash = (ia << 12 | ib) << 4
    for {p,id} in col.pts
      unless ct = @cts[hash|id]
        ct = @cts[hash|id] = Contact(a,b)
      ct.update(col.dist, col.n, p, @t, id)

  find: (v,v2=v) ->
    res = []
    for b in @bodies
      for s in b.transform
        a = s.bounds
        if v.x < a.p2.x && v.y < a.p2.y && a.p1.x < v2.x && a.p1.y < v2.y
          res.push(b)
          break
    res


SpaceIndex = -> {
  start: null
  __proto__: SpaceIndex.methods
}

SpaceIndex.tag = 0

SpaceIndex.methods =
  add: (body, obj) ->
    ins = {
      body, obj, bounds: obj.bounds
      prev: null, next: @start, id: SpaceIndex.tag++
    }
    @start.prev = ins if @start
    @start = ins

  scan: (report) ->
    a = @start.next
    while a
      b = a.prev
      if b.bounds.p1.x > a.bounds.p1.x
        while b.prev && b.bounds.p1.x > a.bounds.p1.x
          b = b.prev
        @reinsert a,b
        if not a.prev then @start = a
      a = a.next
    a = @start
    while a
      b = a.next
      while b && a.bounds.p2.x > b.bounds.p1.x
        if a.bounds.p1.y < b.bounds.p2.y && b.bounds.p1.y < a.bounds.p2.y
          report a.body,a.obj,a.id, b.body,b.obj,b.id
        b = b.next
      a = a.next
    # @index.sort (a,b) -> if a.bounds.p1.x < b.bounds.p1.x then -1 else 1
    # for a,i in @index
    #   b = @index[++i]
    #   while b && a.bounds.p2.x > b.bounds.p1.x
    #     if a.bounds.p1.y < b.bounds.p2.y && b.bounds.p1.y < a.bounds.p2.y
    #       pass a,b
    #     b = @index[++i]

  reinsert: (i,at) ->
    i.next.prev = i.prev if i.next
    i.prev.next = i.next if i.prev
    i.prev = at.prev; i.next = at
    if at.prev
      at.prev.next = i 
    else @start = i
    at.prev = i


exports = window || module.exports
exports.phys = { Vec,Axis, Circle,Poly,Box, Body, Space }
