var drawOmega = function (ctx, outerCircleColor, innerCircleColor) {
  ctx.clearRect(0,0,19,19)

  if (innerCircleColor != null) {
    ctx.save();
    ctx.fillStyle = innerCircleColor;
    ctx.beginPath();
    ctx.moveTo(14.05,9.50);
    ctx.bezierCurveTo(14.05,11.95,12.01,13.94,9.50,13.94);
    ctx.bezierCurveTo(6.99,13.94,4.95,11.95,4.95,9.50);
    ctx.bezierCurveTo(4.95,7.05,6.99,5.06,9.50,5.06);
    ctx.bezierCurveTo(12.01,5.06,14.05,7.05,14.05,9.50);
    ctx.closePath();
    ctx.fill('evenodd');
    ctx.restore();
  }

  ctx.save();
  ctx.fillStyle = outerCircleColor;
  ctx.beginPath();
  ctx.moveTo(14.05,9.50);
  ctx.bezierCurveTo(14.05,11.95,12.01,13.94,9.50,13.94);
  ctx.bezierCurveTo(6.99,13.94,4.95,11.95,4.95,9.50);
  ctx.bezierCurveTo(4.95,7.05,6.99,5.06,9.50,5.06);
  ctx.bezierCurveTo(12.01,5.06,14.05,7.05,14.05,9.50);
  ctx.closePath();
  ctx.moveTo(18.04,9.50);
  ctx.bezierCurveTo(18.04,14.11,14.22,17.85,9.50,17.85);
  ctx.bezierCurveTo(4.78,17.85,0.96,14.11,0.96,9.50);
  ctx.bezierCurveTo(0.96,4.89,4.78,1.15,9.50,1.15);
  ctx.bezierCurveTo(14.22,1.15,18.04,4.89,18.04,9.50);
  ctx.closePath();
  ctx.fill('evenodd');
  ctx.restore();
  ctx.save();
  ctx.fillStyle = outerCircleColor;
};
