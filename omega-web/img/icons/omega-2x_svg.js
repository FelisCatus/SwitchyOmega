var drawOmega2x = function (ctx, outerCircleColor, innerCircleColor) {
  ctx.clearRect(0,0,38,38);

  ctx.lineCap = 'butt';
  ctx.lineJoin = 'miter';
  ctx.miterLimit = 4;

  if (innerCircleColor != null) {
    ctx.fillStyle = innerCircleColor;
    ctx.moveTo(29.008134,19.000226);
    ctx.bezierCurveTo(29.008134,24.527563,24.527338,29.008358,19,29.008358);
    ctx.bezierCurveTo(13.472661,29.008358,8.9918668,24.527563,8.9918668,19.000226);
    ctx.bezierCurveTo(8.9918668,13.472887000000002,13.472661,8.9920918,19,8.9920918);
    ctx.bezierCurveTo(24.527338,8.9920918,29.008134,13.472887,29.008134,19.000226);
    ctx.closePath();
    ctx.fill();
  }

  ctx.fillStyle = outerCircleColor;
  ctx.beginPath();
  ctx.moveTo(29.008134,19.000226);
  ctx.bezierCurveTo(29.008134,24.527563,24.527338,29.008358,19,29.008358);
  ctx.bezierCurveTo(13.472661,29.008358,8.9918668,24.527563,8.9918668,19.000226);
  ctx.bezierCurveTo(8.9918668,13.472887000000002,13.472661,8.9920918,19,8.9920918);
  ctx.bezierCurveTo(24.527338,8.9920918,29.008134,13.472887,29.008134,19.000226);
  ctx.closePath();
  ctx.moveTo(37.8,19);
  ctx.bezierCurveTo(37.8,29.382957,29.382952,37.8,19,37.8);
  ctx.bezierCurveTo(8.6170465,37.8,0.2,29.382955,0.2,19);
  ctx.bezierCurveTo(0.2,8.617046,8.6170465,0.2,19,0.2);
  ctx.bezierCurveTo(29.382952,0.2,37.8,8.617046,37.8,19);
  ctx.closePath();
  ctx.fill('evenodd');
};
