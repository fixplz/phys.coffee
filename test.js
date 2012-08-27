// Generated by CoffeeScript 1.3.3
(function() {
  var bodies, c, canvas, dragging, draggingOffset, drawCircle, drawContact, drawPoly, drawSpace, drawT, i, k, mouseDelta, mouseLast, pos, reqFrame, run, shapes, space, stats, statsEl, t, v, _, _i;

  for (k in phys) {
    v = phys[k];
    this[k] = v;
  }

  canvas = document.getElementById('stage');

  c = canvas.getContext('2d');

  drawPoly = function(poly) {
    var v1, vs, _i, _len;
    vs = poly.verts;
    v1 = vs[0];
    c.beginPath();
    c.moveTo(v1.x, v1.y);
    for (_i = 0, _len = vs.length; _i < _len; _i++) {
      v = vs[_i];
      c.lineTo(v.x, v.y);
    }
    c.closePath();
    return c.fill();
  };

  drawCircle = function(circle) {
    c.beginPath();
    c.arc(circle.center.x, circle.center.y, circle.radius, 0, Math.PI * 2);
    c.closePath();
    return c.fill();
  };

  drawContact = function(ct) {
    c.beginPath();
    c.arc(ct.p.x, ct.p.y, 2.5, 0, Math.PI * 2);
    c.closePath();
    return c.fill();
  };

  drawSpace = function(space) {
    var body, ct, s, _, _i, _j, _len, _len1, _ref, _ref1, _ref2, _results;
    c.clearRect(0, 0, canvas.width, canvas.height);
    c.fillStyle = '#200';
    _ref = space.bodies;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      body = _ref[_i];
      _ref1 = body.transform;
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        s = _ref1[_j];
        switch (false) {
          case !s.verts:
            drawPoly(s);
            break;
          case !s.radius:
            drawCircle(s);
        }
      }
    }
    c.fillStyle = '#0b0';
    _ref2 = space.cts;
    _results = [];
    for (_ in _ref2) {
      ct = _ref2[_];
      if (ct.t === space.t) {
        _results.push(drawContact(ct));
      }
    }
    return _results;
  };

  shapes = [[Box(40, 40)], [Circle(20)], [Box(15, 40), Box(40, 15)]];

  bodies = [];

  for (_ = _i = 0; _i <= 60; _ = ++_i) {
    pos = Vec(150 + 400 * Math.random(), 200 * Math.random());
    i = Math.floor(3 * Math.random());
    bodies.push(Body(pos, shapes[i]));
  }

  bodies.push(Body(Vec(650 / 2, 250), [Box(420, 50)], Infinity, 0), Body(Vec(650 - 80, 200), [Box(150, 50)], Infinity, -.8), Body(Vec(80, 200), [Box(150, 50)], Infinity, .8));

  space = Space(bodies);

  stats = new Stats();

  statsEl = stats.domElement;

  document.getElementById('stage-frame').appendChild(statsEl);

  t = 1 / 120;

  setInterval(function() {
    var b, tgt;
    stats.begin();
    space.update(t, 3);
    stats.end();
    if (dragging) {
      b = dragging;
      tgt = mouseLast.cp().add(draggingOffset);
      return b.vel.addMult(tgt.sub(b.pos), .4 / t).mult(.5);
    }
  }, 1000 * t);

  dragging = null;

  mouseLast = Vec(0, 0);

  mouseDelta = Vec(0, 0);

  draggingOffset = null;

  canvas.onmousemove = function(e) {
    var cur;
    cur = Vec(e.layerX || e.offsetX, e.layerY || e.offsetY);
    return mouseLast.set(cur);
  };

  canvas.onmousedown = function(e) {
    e.preventDefault();
    dragging = space.find(mouseLast)[0];
    if (dragging) {
      return draggingOffset = dragging.pos.cp().sub(mouseLast);
    }
  };

  canvas.onmouseup = function() {
    return dragging = null;
  };

  reqFrame = window.mozRequestAnimationFrame || window.webkitRequestAnimationFrame;

  drawT = 0;

  reqFrame(run = function() {
    reqFrame(run);
    if (space.t !== drawT) {
      drawT = space.t;
      return drawSpace(space);
    }
  });

}).call(this);