
Vec = (x,y) ->
  { x, y, __proto__: Vec.methods }

Vec.methods =
  opp: -> Vec(-@x, -@y)
  mult: (s) -> Vec(s*@x, s*@y)
  add: ({x,y}) -> Vec(@x+x, @y+y)
  sub: ({x,y}) -> Vec(@x-x, @y-y)
  dot: ({x,y}) -> @x*x + @y*y
  # cross: (v) -> -@dot(v.perp())
  cross: ({x,y}) -> -(@x*-y + @y*x)
  perp: -> Vec(-@y, @x)
  len: -> Math.sqrt(@dot(@))
  unit: -> l = @len(); Vec(@x/l, @y/l)
  rotate: ({x,y}) -> Vec(@x*x - @y*y, @y*x + @x*y)
  toString: -> "{#{@x},#{@y}}"

###
Vec.methods =
  cp: -> { x: @x, y: @y, __proto__: @__proto__ }
  opp: -> Vec(-@x, -@y)
  mult: (s) -> @x *= s, @y *= s
  add: ({x,y}) -> @x += x; @y += y
  sub: ({x,y}) -> @x -= x; @y -= y
  dot: ({x,y}) -> @x*x + @y*y
  cross: (v) -> -(@x * -y + @y * x)
  perp: -> y = @y; @y = @x; @x = -y
  len: -> Math.sqrt(@dot(@))
  unit: -> l = @len(); @x /= l, @y /= l
  # rotate: ({x,y}) -> Vec(@x*x - @y*y, @y*x + @x*y)
  rotate: ({x,y}) -> x_ = @x*x - @y*y; y_ = @y*x + @x*y; @x = x_; @y = y_
  toString: -> "{#{@x},#{@y}}"
###

Vec.polar = (a) -> Vec(Math.cos(a), Math.sin(a))

Axis = (n,d) ->
  { n, d, __proto__: Axis.methods }

Axis.methods =
  opp: -> Axis(@n.opp(), @d)
  toString: -> "Axis(#{@n},#{@d})"


Circle = (radius) -> {
  radius
  area: radius*radius * Math.PI
  inertia: radius*radius / 2
  obj: -> { center: null, radius }
  update: (obj,body) ->
    obj.center = body.pos
}


Poly = (verts) -> {
  verts: verts
  axes:
    Poly.sides(verts).map ([v1,v2]) ->
      n = v2.sub(v1).unit().perp()
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
  obj: -> { verts: null, axes: null }
  update: (obj,body) ->
    dir = Vec.polar(body.ang)
    obj.verts = @verts.map (v) -> body.pos.add(dir.rotate(v))
    obj.axes = @axes.map (a) ->
      n = a.n.rotate(dir)
      Axis(n, n.dot(body.pos) + a.d)
}

Poly.sides = (xs) ->
  xs.map (x,i) -> [x, xs[(i+1) % xs.length]]
Poly.sides3 = (xs) ->
  xs.map (x,i) -> [x, xs[(i+1) % xs.length], xs[(i+2) % xs.length]]

Box = (w,h) ->
  Poly([Vec(-w/2,-h/2), Vec(-w/2, h/2), Vec(w/2, h/2), Vec(w/2, -h/2)])


Body = (pos,shapes,density=1) ->
  area = 0; inertia = 0
  for s in shapes
    area += s.area
    inertia += s.inertia
  mass = area * density
  inertia = mass * inertia

  {
    id: Body.tag++
    pos, ang: 0
    vel: Vec(0,0), rot: 0
    snap: Vec(0,0), asnap: 0

    shapes
    transform: s.obj() for s in shapes

    density
    mass, inertia
    invMass: 1 / mass
    invInertia: 1 / inertia

    __proto__: Body.methods
  }

Body.tag = 0

Body.methods =
  update: (gravity, dt) ->
    @pos = @pos.add(@vel.mult(dt)).add(@snap)
    @ang = @ang + @rot*dt + @asnap
    @snap = Vec(0,0)
    @asnap = 0
    unless @mass is Infinity
      @vel = @vel.add(gravity.mult(dt))
    s.update @transform[i], @ for s,i in @shapes
  applySnap: (j, r) ->
    @snap = @snap.add(j.mult(1/@mass))
    @asnap = @asnap + j.dot(r.perp()) * 1/@inertia
  applyVel: (j, r) ->
    @vel = @vel.add(j.mult(1/@mass))
    @rot = @rot + j.dot(r.perp()) * 1/@inertia


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
    pts.push p: v, id: i for v,i in poly1.verts when Collision.containsV(poly2, v)
    pts.push p: v, id: 16+i for v,i in poly2.verts when Collision.containsV(poly1, v)
    pts

  polyPoly: (p1, p2) ->
    a1 = Collision.sepAxisPP(p1, p2)
    a2 = Collision.sepAxisPP(p2, p1)
    if a1 and a2
      a = if a1.d > a2.d then a1 else a2.opp()
      n: a.n, dist: a.d, pts: Collision.findVs p1, p2
    else false

  circleCircle: (c1, c2) ->
    r = c2.center.sub(c1.center)
    min = c1.radius + c2.radius
    return false if r.dot(r) > min*min
    p = c1.center.add(r.mult(0.5 + (c1.radius - 0.5*min)/r.len()))
    n: r.unit(), dist: r.len() - min
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
      [v1,v2] = Poly.sides(p.verts)[i]
      a = p.axes[i]
      d = a.n.cross(c.center)
      corner = (v) -> Collision.circleCircle({center: v, radius: 0}, c)
      switch
        when d > a.n.cross(v1) then corner v1
        when d < a.n.cross(v2) then corner v2
        else {
          n: a.n, dist: max
          pts: [ p: c.center.sub(a.n.mult(c.radius + max/2)), id: i ]
        }

  check: (a,b) ->
    switch
      when a.verts and b.verts then Collision.polyPoly(a,b)
      when a.verts and b.radius then Collision.polyCircle(a,b)
      when a.radius and b.verts
        c = Collision.polyCircle(b,a); if c then c.n = c.n.opp(); c
      when a.radius and b.radius then Collision.circleCircle(a,b)


Contact = -> {
  p: null, t: 0
  jN: 0, jT: 0, r1: null, r2: null, massN: 0, massT: 0, snapDist: 0
  __proto__: Contact.methods
}

Contact.methods =
  update: (@a,@b, dist,@n, @p, @t) ->
    @r1 = p.sub(a.pos)
    @r2 = p.sub(b.pos)

    @massN = @kin(n); @massT = @kin(n.perp())

    @snapDist = 0.2 * -Math.min(0, dist + 0.1)

    @applyVel @n.rotate(Vec(@jN,@jT))

  kin: (n) ->
    1 / ( @a.invMass + @b.invMass +
      @a.invInertia * Math.pow(@r1.cross(n),2) +
      @b.invInertia * Math.pow(@r2.cross(n),2) )

  applySnap: (j) -> @a.applySnap(j.opp(), @r1); @b.applySnap(j, @r2)
  applyVel: (j) -> @a.applyVel(j.opp(), @r1); @b.applyVel(j, @r2)

  rel: (bv,br, av,ar) ->
    bv.add(@r2.perp().mult(br))
      .sub(av).sub(@r1.perp().mult(ar))

  perform: ->
    v = @rel @b.vel, @b.rot, @a.vel, @a.rot
    s = @rel @b.snap, @b.asnap, @a.snap, @a.asnap
    
    snapN = @massN * (@snapDist - s.dot(@n))
    @applySnap @n.mult(snapN) if snapN > 0
    
    jN = @massN * -v.dot(@n)
    jT = @massT * -v.dot(@n.perp())

    newN = Math.max(0, @jN + jN)
    limitT = newN * 0.8
    newT = Math.min(limitT, Math.max(-limitT, @jT + jT))

    @applyVel @n.rotate(Vec(newN - @jN, newT - @jT))

    @jN = newN; @jT = newT


Space = (bodies) -> {
  bodies
  t: 0
  cts: {}
  gravity: Vec(0,200)
  __proto__: Space.methods
}

Space.methods =
  update: (dt, iters) ->
    @t++

    body.update(@gravity, dt) for body in @bodies

    num = @bodies.length
    for i in [0...num] then for j in [i+1...num]
      a = @bodies[i]; b = @bodies[j]
      for sa,ia in a.transform then for sb,ib in b.transform
        if col = Collision.check(sa, sb)
          hash = a.id << 22 | b.id << 12 | ia << 8 | ib << 4
          for {p,id} in col.pts
            unless ct = @cts[hash|id]
              ct = @cts[hash|id] = Contact()
            ct.update(a,b, col.dist, col.n, p, @t, id)

    for id,ct of @cts
      if ct.t+3 <= @t
        delete @cts[id]

    for _ in [0..iters]
      for id,ct of @cts when ct.t == @t
        ct.perform()


exports = window || module.exports
exports.phys = { Vec,Axis, Circle,Poly,Box, Body, Space }
