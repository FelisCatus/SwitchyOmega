var drawOmega2x = function (ctx, outerCircleColor, innerCircleColor) {
  ctx.clearRect(0,0,38,38);

  ctx.lineCap = 'butt';
  ctx.lineJoin = 'miter';
  ctx.miterLimit = 4;

  if (innerCircleColor != null) {
    ctx.fillStyle = innerCircleColor;
    ctx.moveTo(29,19);
    ctx.bezierCurveTo(29,24.53,24.52,29,19,29);
    ctx.bezierCurveTo(13.47,29,9,24.52,9,19);
    ctx.bezierCurveTo(9,13.47,13.48,9,19,9);
    ctx.bezierCurveTo(24.53,9,29,13.48,29,19);
    ctx.closePath();
    ctx.fill();
  }

  ctx.fillStyle = outerCircleColor;
  ctx.beginPath();
  ctx.moveTo(29,19);
  ctx.bezierCurveTo(29,24.53,24.52,29,19,29);
  ctx.bezierCurveTo(13.47,29,9,24.52,9,19);
  ctx.bezierCurveTo(9,13.47,13.48,9,19,9);
  ctx.bezierCurveTo(24.53,9,29,13.48,29,19);
  ctx.closePath();
  ctx.moveTo(37.8,19);
  ctx.bezierCurveTo(37.8,29.38,29.38,37.8,19,37.8);
  ctx.bezierCurveTo(8.62,37.8,0.2,29.38,0.2,19);
  ctx.bezierCurveTo(0.2,8.62,8.62,0.2,19,0.2);
  ctx.bezierCurveTo(29.38,0.2,37.8,8.62,37.8,19);
  ctx.closePath();
  ctx.fill('evenodd');
};
