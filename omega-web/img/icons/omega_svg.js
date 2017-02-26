var drawOmega = function (ctx, outerCircleColor, innerCircleColor) {
  ctx.clearRect(0,0,19,19)

  if (innerCircleColor != null) {
    ctx.save();
    ctx.fillStyle = innerCircleColor;
    ctx.beginPath();
    ctx.moveTo(14.5,9.5);
    ctx.bezierCurveTo(14.5,12.26,12.26,14.5,9.5,14.5);
    ctx.bezierCurveTo(6.74,14.5,4.5,12.26,4.5,9.5);
    ctx.bezierCurveTo(4.5,6.74,6.74,4.5,9.5,4.5);
    ctx.bezierCurveTo(12.26,4.5,14.5,6.74,14.5,9.5);
    ctx.closePath();
    ctx.fill('evenodd');
    ctx.restore();
  }

  ctx.save();
  ctx.fillStyle = outerCircleColor;
  ctx.beginPath();
  ctx.moveTo(14.5,9.5);
  ctx.bezierCurveTo(14.5,12.26,12.26,14.5,9.5,14.5);
  ctx.bezierCurveTo(6.74,14.5,4.5,12.26,4.5,9.5);
  ctx.bezierCurveTo(4.5,6.74,6.74,4.5,9.5,4.5);
  ctx.bezierCurveTo(12.26,4.5,14.5,6.74,14.5,9.5);
  ctx.closePath();
  ctx.moveTo(18.9,9.5);
  ctx.bezierCurveTo(18.9,14.67,14.67,18.9,9.5,18.9);
  ctx.bezierCurveTo(4.2,18.9,0.1,14.7,0.1,9.5);
  ctx.bezierCurveTo(0.1,4.2,4.2,0.1,9.5,0.1);
  ctx.bezierCurveTo(14.7,0.1,18.9,4.3,18.9,9.5);
  ctx.closePath();
  ctx.fill('evenodd');
  ctx.restore();
  ctx.save();
  ctx.fillStyle = outerCircleColor;
};
