var drawOmega2x = function (ctx, outerCircleColor, innerCircleColor) {
  ctx.clearRect(0,0,38,38);

  ctx.lineCap = 'butt';
  ctx.lineJoin = 'miter';
  ctx.miterLimit = 4;

  if (innerCircleColor != null) {
    ctx.fillStyle = innerCircleColor;
    ctx.moveTo(36.077892,19);
    ctx.bezierCurveTo(36.077892,28.222652,28.431858,35.699084,19,35.699084);
    ctx.bezierCurveTo(9.5681407,35.699084,1.922108,28.22265,1.922108,19);
    ctx.bezierCurveTo(1.922108,9.77735,9.5681407,2.300916,19,2.300916);
    ctx.bezierCurveTo(28.431858,2.300916,36.077892,9.77735,36.077892,19);
    ctx.closePath();
    ctx.fill();
  }

  ctx.fillStyle = outerCircleColor;
  ctx.beginPath();
  ctx.moveTo(28.091374,19.0002);
  ctx.bezierCurveTo(28.091374,23.909854,24.021026,27.889916,19,27.889916);
  ctx.bezierCurveTo(13.978973,27.889916,9.9086265,23.909854,9.9086265,19.0002);
  ctx.bezierCurveTo(9.9086265,14.090546,13.978973,10.110484,19,10.110484);
  ctx.bezierCurveTo(24.021026,10.110484,28.091374000000002,14.090546,28.091374000000002,19.0002);
  ctx.closePath();
  ctx.moveTo(36.077892,19);
  ctx.bezierCurveTo(36.077892,28.222652,28.431858,35.699084,19,35.699084);
  ctx.bezierCurveTo(9.5681407,35.699084,1.922108,28.22265,1.922108,19);
  ctx.bezierCurveTo(1.922108,9.77735,9.5681407,2.300916,19,2.300916);
  ctx.bezierCurveTo(28.431858,2.300916,36.077892,9.77735,36.077892,19);
  ctx.closePath();
  ctx.fill('evenodd');
};
