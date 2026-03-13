import 'package:flutter/material.dart';

class LogoPainter extends CustomPainter {
  final double progress;

  LogoPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildLogoPath(size);

    final metrics = path.computeMetrics();

    // ===============================
    // FASES DE ANIMACIÓN
    // ===============================

    final p = progress.clamp(0.0, 1.0);

    // 0% - 85% => recorrido (mecha)
    final burn = p < 0.85 ? p / 0.85 : 1.0;

    // 85% - 100% => explosión (glow)
    final glow = p > 0.85 ? (p - 0.85) / 0.15 : 0.0;

    final animatedPath = Path();

    // RECORRIDO DEL LOGO
    for (final metric in metrics) {
      final length = metric.length;

      // Cuánto del path dibujar
      final end = length * burn;

      final segment = metric.extractPath(0, end);

      animatedPath.addPath(segment, Offset.zero);

      // CHISPA (PUNTA ENCENDIDA)

      final tangent = metric.getTangentForOffset(end);

      if (tangent != null) {
        final sparkSize = size.width * (0.012 + glow * 0.01);

        canvas.drawCircle(
          tangent.position,
          sparkSize,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + glow * 20),
        );
      }
    }

    if (glow > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * (0.01 + glow * 0.015)
          ..color = Colors.white.withValues(alpha: glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + glow * 25),
      );
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.008
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.8),
          Colors.blueAccent.withValues(alpha: 0.6 + glow * 0.4),
          Colors.white,
          Colors.transparent,
        ],
        stops: const [0, 0.4, 0.5, 0.6, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(animatedPath, paint);
  }

  Path buildLogoPath(Size size) {
    final path = Path();

    Path path_0 = Path();
    path_0.moveTo(0, size.height * 0.5000000);
    path_0.lineTo(0, size.height);
    path_0.lineTo(size.width, size.height);
    path_0.lineTo(size.width, 0);
    path_0.lineTo(0, 0);
    path_0.close();
    path_0.moveTo(size.width * 0.5458984, size.height * 0.08984375);
    path_0.cubicTo(
      size.width * 0.5464844,
      size.height * 0.09082031,
      size.width * 0.5503906,
      size.height * 0.09179688,
      size.width * 0.5542969,
      size.height * 0.09179688,
    );
    path_0.cubicTo(
      size.width * 0.5707031,
      size.height * 0.09179688,
      size.width * 0.5843750,
      size.height * 0.09941406,
      size.width * 0.5914063,
      size.height * 0.1121094,
    );
    path_0.cubicTo(
      size.width * 0.5943359,
      size.height * 0.1175781,
      size.width * 0.5947266,
      size.height * 0.1296875,
      size.width * 0.5957031,
      size.height * 0.2392578,
    );
    path_0.lineTo(size.width * 0.5966797, size.height * 0.3603516);
    path_0.lineTo(size.width * 0.6123047, size.height * 0.3613281);
    path_0.cubicTo(
      size.width * 0.6298828,
      size.height * 0.3625000,
      size.width * 0.6378906,
      size.height * 0.3660156,
      size.width * 0.6437500,
      size.height * 0.3757813,
    );
    path_0.cubicTo(
      size.width * 0.6472656,
      size.height * 0.3814453,
      size.width * 0.6474609,
      size.height * 0.3875000,
      size.width * 0.6480469,
      size.height * 0.4613281,
    );
    path_0.cubicTo(
      size.width * 0.6484375,
      size.height * 0.5164062,
      size.width * 0.6478516,
      size.height * 0.5435547,
      size.width * 0.6462891,
      size.height * 0.5492187,
    );
    path_0.cubicTo(
      size.width * 0.6435547,
      size.height * 0.5595703,
      size.width * 0.6322266,
      size.height * 0.5710937,
      size.width * 0.6220703,
      size.height * 0.5740234,
    );
    path_0.cubicTo(
      size.width * 0.6167969,
      size.height * 0.5753906,
      size.width * 0.5740234,
      size.height * 0.5761719,
      size.width * 0.4873047,
      size.height * 0.5761719,
    );
    path_0.cubicTo(
      size.width * 0.3683594,
      size.height * 0.5761719,
      size.width * 0.3597656,
      size.height * 0.5757813,
      size.width * 0.3525391,
      size.height * 0.5724609,
    );
    path_0.cubicTo(
      size.width * 0.3429688,
      size.height * 0.5681641,
      size.width * 0.3347656,
      size.height * 0.5589844,
      size.width * 0.3320313,
      size.height * 0.5492188,
    );
    path_0.cubicTo(
      size.width * 0.3304688,
      size.height * 0.5443359,
      size.width * 0.3300781,
      size.height * 0.4957031,
      size.width * 0.3304688,
      size.height * 0.3933594,
    );
    path_0.lineTo(size.width * 0.3310547, size.height * 0.2449219);
    path_0.lineTo(size.width * 0.3359375, size.height * 0.2376953);
    path_0.cubicTo(
      size.width * 0.3388672,
      size.height * 0.2333984,
      size.width * 0.3449219,
      size.height * 0.2283203,
      size.width * 0.3503906,
      size.height * 0.2255859,
    );
    path_0.lineTo(size.width * 0.3601563, size.height * 0.2207031);
    path_0.lineTo(size.width * 0.4226563, size.height * 0.2207031);
    path_0.cubicTo(
      size.width * 0.5015625,
      size.height * 0.2207031,
      size.width * 0.4955078,
      size.height * 0.2185547,
      size.width * 0.5193359,
      size.height * 0.2546875,
    );
    path_0.lineTo(size.width * 0.5361328, size.height * 0.2802734);
    path_0.lineTo(size.width * 0.5501953, size.height * 0.2808594);
    path_0.lineTo(size.width * 0.5644531, size.height * 0.2814453);
    path_0.lineTo(size.width * 0.5648438, size.height * 0.2048828);
    path_0.cubicTo(
      size.width * 0.5652344,
      size.height * 0.1525391,
      size.width * 0.5648438,
      size.height * 0.1273438,
      size.width * 0.5632813,
      size.height * 0.1253906,
    );
    path_0.cubicTo(
      size.width * 0.5617188,
      size.height * 0.1232422,
      size.width * 0.5591797,
      size.height * 0.1228516,
      size.width * 0.5525391,
      size.height * 0.1240234,
    );
    path_0.cubicTo(
      size.width * 0.5441406,
      size.height * 0.1255859,
      size.width * 0.4402344,
      size.height * 0.1259766,
      size.width * 0.4208984,
      size.height * 0.1246094,
    );
    path_0.lineTo(size.width * 0.4111328, size.height * 0.1240234);
    path_0.lineTo(size.width * 0.4101563, size.height * 0.1650391);
    path_0.lineTo(size.width * 0.4091797, size.height * 0.2060547);
    path_0.lineTo(size.width * 0.3951172, size.height * 0.2066406);
    path_0.lineTo(size.width * 0.3808594, size.height * 0.2072266);
    path_0.lineTo(size.width * 0.3808594, size.height * 0.1630859);
    path_0.cubicTo(
      size.width * 0.3808594,
      size.height * 0.1230469,
      size.width * 0.3812500,
      size.height * 0.1183594,
      size.width * 0.3847656,
      size.height * 0.1113281,
    );
    path_0.cubicTo(
      size.width * 0.3908203,
      size.height * 0.09941406,
      size.width * 0.4048828,
      size.height * 0.09179688,
      size.width * 0.4212891,
      size.height * 0.09179688,
    );
    path_0.cubicTo(
      size.width * 0.4246094,
      size.height * 0.09179688,
      size.width * 0.4281250,
      size.height * 0.09082031,
      size.width * 0.4287109,
      size.height * 0.08984375,
    );
    path_0.cubicTo(
      size.width * 0.4294922,
      size.height * 0.08867187,
      size.width * 0.4511719,
      size.height * 0.08789063,
      size.width * 0.4873047,
      size.height * 0.08789063,
    );
    path_0.cubicTo(
      size.width * 0.5234375,
      size.height * 0.08789063,
      size.width * 0.5451172,
      size.height * 0.08867187,
      size.width * 0.5458984,
      size.height * 0.08984375,
    );
    path_0.moveTo(size.width * 0.4482422, size.height * 0.5916016);
    path_0.cubicTo(
      size.width * 0.4505859,
      size.height * 0.5994141,
      size.width * 0.4394531,
      size.height * 0.6158203,
      size.width * 0.4283203,
      size.height * 0.6203125,
    );
    path_0.cubicTo(
      size.width * 0.4203125,
      size.height * 0.6238281,
      size.width * 0.4078125,
      size.height * 0.6238281,
      size.width * 0.3998047,
      size.height * 0.6203125,
    );
    path_0.cubicTo(
      size.width * 0.3923828,
      size.height * 0.6173828,
      size.width * 0.3814453,
      size.height * 0.6054687,
      size.width * 0.3796875,
      size.height * 0.5986328,
    );
    path_0.cubicTo(
      size.width * 0.3771484,
      size.height * 0.5880859,
      size.width * 0.3779297,
      size.height * 0.5878906,
      size.width * 0.4138672,
      size.height * 0.5878906,
    );
    path_0.cubicTo(
      size.width * 0.4445313,
      size.height * 0.5878906,
      size.width * 0.4470703,
      size.height * 0.5880859,
      size.width * 0.4482422,
      size.height * 0.5916016,
    );
    path_0.moveTo(size.width * 0.5898438, size.height * 0.5906250);
    path_0.cubicTo(
      size.width * 0.5931641,
      size.height * 0.5949219,
      size.width * 0.5861328,
      size.height * 0.6095703,
      size.width * 0.5775391,
      size.height * 0.6160156,
    );
    path_0.cubicTo(
      size.width * 0.5587891,
      size.height * 0.6302734,
      size.width * 0.5279297,
      size.height * 0.6207031,
      size.width * 0.5224609,
      size.height * 0.5990234,
    );
    path_0.cubicTo(
      size.width * 0.5197266,
      size.height * 0.5880859,
      size.width * 0.5205078,
      size.height * 0.5878906,
      size.width * 0.5552734,
      size.height * 0.5878906,
    );
    path_0.cubicTo(
      size.width * 0.5808594,
      size.height * 0.5878906,
      size.width * 0.5878906,
      size.height * 0.5884766,
      size.width * 0.5898438,
      size.height * 0.5906250,
    );
    path_0.moveTo(size.width * 0.3275391, size.height * 0.6994141);
    path_0.cubicTo(
      size.width * 0.3378906,
      size.height * 0.7044922,
      size.width * 0.3460938,
      size.height * 0.7171875,
      size.width * 0.3464844,
      size.height * 0.7287109,
    );
    path_0.cubicTo(
      size.width * 0.3466797,
      size.height * 0.7369141,
      size.width * 0.3439453,
      size.height * 0.7402344,
      size.width * 0.3369141,
      size.height * 0.7402344,
    );
    path_0.cubicTo(
      size.width * 0.3318359,
      size.height * 0.7402344,
      size.width * 0.3281250,
      size.height * 0.7367187,
      size.width * 0.3281250,
      size.height * 0.7320312,
    );
    path_0.cubicTo(
      size.width * 0.3281250,
      size.height * 0.7203125,
      size.width * 0.3162109,
      size.height * 0.7115234,
      size.width * 0.3033203,
      size.height * 0.7134766,
    );
    path_0.cubicTo(
      size.width * 0.2890625,
      size.height * 0.7158203,
      size.width * 0.2880859,
      size.height * 0.7183594,
      size.width * 0.2875000,
      size.height * 0.7566406,
    );
    path_0.lineTo(size.width * 0.2869141, size.height * 0.7904297);
    path_0.lineTo(size.width * 0.2919922, size.height * 0.7964844);
    path_0.cubicTo(
      size.width * 0.2964844,
      size.height * 0.8017578,
      size.width * 0.2986328,
      size.height * 0.8027344,
      size.width * 0.3060547,
      size.height * 0.8027344,
    );
    path_0.cubicTo(
      size.width * 0.3107422,
      size.height * 0.8027344,
      size.width * 0.3164063,
      size.height * 0.8017578,
      size.width * 0.3185547,
      size.height * 0.8007812,
    );
    path_0.cubicTo(
      size.width * 0.3232422,
      size.height * 0.7982422,
      size.width * 0.3281250,
      size.height * 0.7888672,
      size.width * 0.3281250,
      size.height * 0.7822266,
    );
    path_0.cubicTo(
      size.width * 0.3281250,
      size.height * 0.7775391,
      size.width * 0.3275391,
      size.height * 0.7773437,
      size.width * 0.3179688,
      size.height * 0.7773437,
    );
    path_0.cubicTo(
      size.width * 0.3072266,
      size.height * 0.7773437,
      size.width * 0.3007813,
      size.height * 0.7736328,
      size.width * 0.3007813,
      size.height * 0.7673828,
    );
    path_0.cubicTo(
      size.width * 0.3007813,
      size.height * 0.7601562,
      size.width * 0.3060547,
      size.height * 0.7578125,
      size.width * 0.3234375,
      size.height * 0.7578125,
    );
    path_0.cubicTo(
      size.width * 0.3453125,
      size.height * 0.7578125,
      size.width * 0.3476563,
      size.height * 0.7599609,
      size.width * 0.3476563,
      size.height * 0.7796875,
    );
    path_0.cubicTo(
      size.width * 0.3474609,
      size.height * 0.8062500,
      size.width * 0.3357422,
      size.height * 0.8201172,
      size.width * 0.3123047,
      size.height * 0.8218750,
    );
    path_0.cubicTo(
      size.width * 0.2916016,
      size.height * 0.8234375,
      size.width * 0.2744141,
      size.height * 0.8128906,
      size.width * 0.2697266,
      size.height * 0.7955078,
    );
    path_0.cubicTo(
      size.width * 0.2669922,
      size.height * 0.7857422,
      size.width * 0.2669922,
      size.height * 0.7316406,
      size.width * 0.2697266,
      size.height * 0.7216797,
    );
    path_0.cubicTo(
      size.width * 0.2746094,
      size.height * 0.7039062,
      size.width * 0.2863281,
      size.height * 0.6955078,
      size.width * 0.3064453,
      size.height * 0.6953125,
    );
    path_0.cubicTo(
      size.width * 0.3154297,
      size.height * 0.6953125,
      size.width * 0.3214844,
      size.height * 0.6964844,
      size.width * 0.3275391,
      size.height * 0.6994141,
    );
    path_0.moveTo(size.width * 0.6939453, size.height * 0.6980469);
    path_0.cubicTo(
      size.width * 0.7060547,
      size.height * 0.7033203,
      size.width * 0.7148438,
      size.height * 0.7162109,
      size.width * 0.7148438,
      size.height * 0.7292969,
    );
    path_0.cubicTo(
      size.width * 0.7148438,
      size.height * 0.7365234,
      size.width * 0.7119141,
      size.height * 0.7402344,
      size.width * 0.7058594,
      size.height * 0.7402344,
    );
    path_0.cubicTo(
      size.width * 0.7007813,
      size.height * 0.7402344,
      size.width * 0.6980469,
      size.height * 0.7373047,
      size.width * 0.6964844,
      size.height * 0.7292969,
    );
    path_0.cubicTo(
      size.width * 0.6943359,
      size.height * 0.7193359,
      size.width * 0.6869141,
      size.height * 0.7138672,
      size.width * 0.6753906,
      size.height * 0.7138672,
    );
    path_0.cubicTo(
      size.width * 0.6671875,
      size.height * 0.7138672,
      size.width * 0.6650391,
      size.height * 0.7146484,
      size.width * 0.6609375,
      size.height * 0.7193359,
    );
    path_0.cubicTo(
      size.width * 0.6564453,
      size.height * 0.7246094,
      size.width * 0.6562500,
      size.height * 0.7257813,
      size.width * 0.6562500,
      size.height * 0.7568359,
    );
    path_0.cubicTo(
      size.width * 0.6562500,
      size.height * 0.7910156,
      size.width * 0.6574219,
      size.height * 0.7970703,
      size.width * 0.6654297,
      size.height * 0.8005859,
    );
    path_0.cubicTo(
      size.width * 0.6781250,
      size.height * 0.8064453,
      size.width * 0.6921875,
      size.height * 0.8009766,
      size.width * 0.6953125,
      size.height * 0.7890625,
    );
    path_0.cubicTo(
      size.width * 0.6964844,
      size.height * 0.7847656,
      size.width * 0.6968750,
      size.height * 0.7802734,
      size.width * 0.6962891,
      size.height * 0.7792969,
    );
    path_0.cubicTo(
      size.width * 0.6957031,
      size.height * 0.7781250,
      size.width * 0.6912109,
      size.height * 0.7773438,
      size.width * 0.6863281,
      size.height * 0.7773438,
    );
    path_0.cubicTo(
      size.width * 0.6744141,
      size.height * 0.7773438,
      size.width * 0.6699219,
      size.height * 0.7746094,
      size.width * 0.6699219,
      size.height * 0.7675781,
    );
    path_0.cubicTo(
      size.width * 0.6699219,
      size.height * 0.7597656,
      size.width * 0.6744141,
      size.height * 0.7578125,
      size.width * 0.6927734,
      size.height * 0.7578125,
    );
    path_0.cubicTo(
      size.width * 0.7144531,
      size.height * 0.7578125,
      size.width * 0.7158203,
      size.height * 0.7591797,
      size.width * 0.7158203,
      size.height * 0.7796875,
    );
    path_0.cubicTo(
      size.width * 0.7156250,
      size.height * 0.7927734,
      size.width * 0.7148438,
      size.height * 0.7974609,
      size.width * 0.7113281,
      size.height * 0.8037109,
    );
    path_0.cubicTo(
      size.width * 0.7042969,
      size.height * 0.8160156,
      size.width * 0.6953125,
      size.height * 0.8210937,
      size.width * 0.6787109,
      size.height * 0.8218750,
    );
    path_0.cubicTo(
      size.width * 0.6619141,
      size.height * 0.8228516,
      size.width * 0.6517578,
      size.height * 0.8185547,
      size.width * 0.6431641,
      size.height * 0.8072266,
    );
    path_0.lineTo(size.width * 0.6376953, size.height * 0.8001953);
    path_0.lineTo(size.width * 0.6371094, size.height * 0.7628906);
    path_0.cubicTo(
      size.width * 0.6363281,
      size.height * 0.7158203,
      size.width * 0.6386719,
      size.height * 0.7083984,
      size.width * 0.6572266,
      size.height * 0.6986328,
    );
    path_0.cubicTo(
      size.width * 0.6646484,
      size.height * 0.6947266,
      size.width * 0.6853516,
      size.height * 0.6943359,
      size.width * 0.6939453,
      size.height * 0.6980469,
    );
    path_0.moveTo(size.width * 0.4564453, size.height * 0.6994141);
    path_0.cubicTo(
      size.width * 0.4695313,
      size.height * 0.7042969,
      size.width * 0.4785156,
      size.height * 0.7179687,
      size.width * 0.4785156,
      size.height * 0.7332031,
    );
    path_0.cubicTo(
      size.width * 0.4785156,
      size.height * 0.7441406,
      size.width * 0.4757813,
      size.height * 0.7513672,
      size.width * 0.4691406,
      size.height * 0.7585937,
    );
    path_0.cubicTo(
      size.width * 0.4613281,
      size.height * 0.7667969,
      size.width * 0.4531250,
      size.height * 0.7695313,
      size.width * 0.4355469,
      size.height * 0.7695313,
    );
    path_0.lineTo(size.width * 0.4199219, size.height * 0.7695313);
    path_0.lineTo(size.width * 0.4199219, size.height * 0.7927734);
    path_0.cubicTo(
      size.width * 0.4199219,
      size.height * 0.8179687,
      size.width * 0.4183594,
      size.height * 0.8222656,
      size.width * 0.4093750,
      size.height * 0.8222656,
    );
    path_0.cubicTo(
      size.width * 0.4005859,
      size.height * 0.8222656,
      size.width * 0.4003906,
      size.height * 0.8207031,
      size.width * 0.4003906,
      size.height * 0.7605469,
    );
    path_0.cubicTo(
      size.width * 0.4003906,
      size.height * 0.7111328,
      size.width * 0.4007813,
      size.height * 0.7029297,
      size.width * 0.4035156,
      size.height * 0.7003906,
    );
    path_0.cubicTo(
      size.width * 0.4058594,
      size.height * 0.6978516,
      size.width * 0.4111328,
      size.height * 0.6972656,
      size.width * 0.4287109,
      size.height * 0.6972656,
    );
    path_0.cubicTo(
      size.width * 0.4410156,
      size.height * 0.6972656,
      size.width * 0.4533203,
      size.height * 0.6982422,
      size.width * 0.4564453,
      size.height * 0.6994141,
    );
    path_0.moveTo(size.width * 0.5781250, size.height * 0.7011719);
    path_0.cubicTo(
      size.width * 0.6015625,
      size.height * 0.7130859,
      size.width * 0.6033203,
      size.height * 0.7488281,
      size.width * 0.5814453,
      size.height * 0.7632812,
    );
    path_0.cubicTo(
      size.width * 0.5748047,
      size.height * 0.7677734,
      size.width * 0.5707031,
      size.height * 0.7687500,
      size.width * 0.5558594,
      size.height * 0.7695312,
    );
    path_0.lineTo(size.width * 0.5380859, size.height * 0.7705078);
    path_0.lineTo(size.width * 0.5380859, size.height * 0.7931641);
    path_0.cubicTo(
      size.width * 0.5378906,
      size.height * 0.8181641,
      size.width * 0.5365234,
      size.height * 0.8222656,
      size.width * 0.5273438,
      size.height * 0.8222656,
    );
    path_0.cubicTo(
      size.width * 0.5173828,
      size.height * 0.8222656,
      size.width * 0.5171875,
      size.height * 0.8212891,
      size.width * 0.5185547,
      size.height * 0.7593750,
    );
    path_0.cubicTo(
      size.width * 0.5195313,
      size.height * 0.7265625,
      size.width * 0.5208984,
      size.height * 0.7011719,
      size.width * 0.5218750,
      size.height * 0.6996094,
    );
    path_0.cubicTo(
      size.width * 0.5232422,
      size.height * 0.6980469,
      size.width * 0.5308594,
      size.height * 0.6972656,
      size.width * 0.5472656,
      size.height * 0.6972656,
    );
    path_0.cubicTo(
      size.width * 0.5666016,
      size.height * 0.6972656,
      size.width * 0.5716797,
      size.height * 0.6978516,
      size.width * 0.5781250,
      size.height * 0.7011719,
    );
    path_0.moveTo(size.width * 0.3808594, size.height * 0.8027344);
    path_0.cubicTo(
      size.width * 0.3855469,
      size.height * 0.8074219,
      size.width * 0.3857422,
      size.height * 0.8121094,
      size.width * 0.3816406,
      size.height * 0.8179687,
    );
    path_0.cubicTo(
      size.width * 0.3783203,
      size.height * 0.8226562,
      size.width * 0.3695313,
      size.height * 0.8238281,
      size.width * 0.3656250,
      size.height * 0.8199219,
    );
    path_0.cubicTo(
      size.width * 0.3623047,
      size.height * 0.8166016,
      size.width * 0.3626953,
      size.height * 0.8054687,
      size.width * 0.3664063,
      size.height * 0.8019531,
    );
    path_0.cubicTo(
      size.width * 0.3705078,
      size.height * 0.7976562,
      size.width * 0.3761719,
      size.height * 0.7980469,
      size.width * 0.3808594,
      size.height * 0.8027344,
    );
    path_0.moveTo(size.width * 0.5001953, size.height * 0.8029297);
    path_0.cubicTo(
      size.width * 0.5048828,
      size.height * 0.8076172,
      size.width * 0.5041016,
      size.height * 0.8175781,
      size.width * 0.4986328,
      size.height * 0.8216797,
    );
    path_0.cubicTo(
      size.width * 0.4869141,
      size.height * 0.8304687,
      size.width * 0.4740234,
      size.height * 0.8130859,
      size.width * 0.4843750,
      size.height * 0.8027344,
    );
    path_0.cubicTo(
      size.width * 0.4894531,
      size.height * 0.7976562,
      size.width * 0.4951172,
      size.height * 0.7978516,
      size.width * 0.5001953,
      size.height * 0.8029297,
    );
    path_0.moveTo(size.width * 0.6175781, size.height * 0.8021484);
    path_0.cubicTo(
      size.width * 0.6226563,
      size.height * 0.8066406,
      size.width * 0.6222656,
      size.height * 0.8173828,
      size.width * 0.6167969,
      size.height * 0.8210938,
    );
    path_0.cubicTo(
      size.width * 0.6144531,
      size.height * 0.8228516,
      size.width * 0.6111328,
      size.height * 0.8242188,
      size.width * 0.6095703,
      size.height * 0.8242188,
    );
    path_0.cubicTo(
      size.width * 0.6046875,
      size.height * 0.8242188,
      size.width * 0.5996094,
      size.height * 0.8179688,
      size.width * 0.5996094,
      size.height * 0.8119141,
    );
    path_0.cubicTo(
      size.width * 0.5996094,
      size.height * 0.8007813,
      size.width * 0.6097656,
      size.height * 0.7951172,
      size.width * 0.6175781,
      size.height * 0.8021484,
    );

    // Paint paint_0_fill = Paint()..style=PaintingStyle.fill;
    // paint_0_fill.color = Color(0xff000000).withOpacity(1.0);
    // canvas.drawPath(path_0,paint_0_fill);

    Path path_1 = Path();
    path_1.moveTo(size.width * 0.4359375, size.height * 0.09804688);
    path_1.cubicTo(
      size.width * 0.4367187,
      size.height * 0.1000000,
      size.width * 0.4484375,
      size.height * 0.1007813,
      size.width * 0.4845703,
      size.height * 0.1011719,
    );
    path_1.cubicTo(
      size.width * 0.5326172,
      size.height * 0.1017578,
      size.width * 0.5421875,
      size.height * 0.1011719,
      size.width * 0.5400391,
      size.height * 0.09765625,
    );
    path_1.cubicTo(
      size.width * 0.5392578,
      size.height * 0.09648438,
      size.width * 0.5183594,
      size.height * 0.09570313,
      size.width * 0.4871094,
      size.height * 0.09570313,
    );
    path_1.cubicTo(
      size.width * 0.4464844,
      size.height * 0.09570313,
      size.width * 0.4353516,
      size.height * 0.09628906,
      size.width * 0.4359375,
      size.height * 0.09804688,
    );
    path_1.moveTo(size.width * 0.3607422, size.height * 0.2630859);
    path_1.cubicTo(
      size.width * 0.3599609,
      size.height * 0.2636719,
      size.width * 0.3593750,
      size.height * 0.3261719,
      size.width * 0.3595703,
      size.height * 0.4017578,
    );
    path_1.cubicTo(
      size.width * 0.3595703,
      size.height * 0.5351563,
      size.width * 0.3597656,
      size.height * 0.5394531,
      size.width * 0.3634766,
      size.height * 0.5431641,
    );
    path_1.cubicTo(
      size.width * 0.3669922,
      size.height * 0.5466797,
      size.width * 0.3710938,
      size.height * 0.5468750,
      size.width * 0.4851562,
      size.height * 0.5468750,
    );
    path_1.cubicTo(
      size.width * 0.5500000,
      size.height * 0.5468750,
      size.width * 0.6044922,
      size.height * 0.5462891,
      size.width * 0.6062500,
      size.height * 0.5457031,
    );
    path_1.cubicTo(
      size.width * 0.6089844,
      size.height * 0.5447266,
      size.width * 0.6093750,
      size.height * 0.5365234,
      size.width * 0.6093750,
      size.height * 0.4744141,
    );
    path_1.cubicTo(
      size.width * 0.6093750,
      size.height * 0.4199219,
      size.width * 0.6087891,
      size.height * 0.4039062,
      size.width * 0.6070313,
      size.height * 0.4033203,
    );
    path_1.cubicTo(
      size.width * 0.5962891,
      size.height * 0.3998047,
      size.width * 0.5966797,
      size.height * 0.3978516,
      size.width * 0.5957031,
      size.height * 0.4433594,
    );
    path_1.cubicTo(
      size.width * 0.5945312,
      size.height * 0.4908203,
      size.width * 0.5945312,
      size.height * 0.4912109,
      size.width * 0.5773438,
      size.height * 0.5072266,
    );
    path_1.cubicTo(
      size.width * 0.5619141,
      size.height * 0.5216797,
      size.width * 0.5630859,
      size.height * 0.5214844,
      size.width * 0.4818359,
      size.height * 0.5214844,
    );
    path_1.cubicTo(
      size.width * 0.4326172,
      size.height * 0.5214844,
      size.width * 0.4072266,
      size.height * 0.5207031,
      size.width * 0.4021484,
      size.height * 0.5191406,
    );
    path_1.cubicTo(
      size.width * 0.3919922,
      size.height * 0.5162109,
      size.width * 0.3792969,
      size.height * 0.5048828,
      size.width * 0.3748047,
      size.height * 0.4953125,
    );
    path_1.cubicTo(
      size.width * 0.3716797,
      size.height * 0.4882813,
      size.width * 0.3710938,
      size.height * 0.4818359,
      size.width * 0.3710938,
      size.height * 0.4437500,
    );
    path_1.cubicTo(
      size.width * 0.3710938,
      size.height * 0.3988281,
      size.width * 0.3716797,
      size.height * 0.3953125,
      size.width * 0.3798828,
      size.height * 0.3851563,
    );
    path_1.cubicTo(
      size.width * 0.3998047,
      size.height * 0.3605469,
      size.width * 0.3917969,
      size.height * 0.3625000,
      size.width * 0.4804688,
      size.height * 0.3613281,
    );
    path_1.lineTo(size.width * 0.5556641, size.height * 0.3603516);
    path_1.lineTo(size.width * 0.5556641, size.height * 0.3232422);
    path_1.lineTo(size.width * 0.5371094, size.height * 0.3222656);
    path_1.cubicTo(
      size.width * 0.5113281,
      size.height * 0.3208984,
      size.width * 0.5087891,
      size.height * 0.3191406,
      size.width * 0.4878906,
      size.height * 0.2875000,
    );
    path_1.lineTo(size.width * 0.4707031, size.height * 0.2617188);
    path_1.lineTo(size.width * 0.4164062, size.height * 0.2617188);
    path_1.cubicTo(
      size.width * 0.3865234,
      size.height * 0.2617188,
      size.width * 0.3613281,
      size.height * 0.2623047,
      size.width * 0.3607422,
      size.height * 0.2630859,
    );

    // Paint paint_1_fill = Paint()..style=PaintingStyle.fill;
    // paint_1_fill.color = Color(0xff000000).withOpacity(1.0);
    // canvas.drawPath(path_1,paint_1_fill);

    Path path_2 = Path();
    path_2.moveTo(size.width * 0.4800781, size.height * 0.4019531);
    path_2.lineTo(size.width * 0.4101563, size.height * 0.4023438);
    path_2.lineTo(size.width * 0.4101563, size.height * 0.4392578);
    path_2.cubicTo(
      size.width * 0.4101563,
      size.height * 0.4679687,
      size.width * 0.4107422,
      size.height * 0.4765625,
      size.width * 0.4128906,
      size.height * 0.4783203,
    );
    path_2.cubicTo(
      size.width * 0.4146484,
      size.height * 0.4798828,
      size.width * 0.4355469,
      size.height * 0.4804688,
      size.width * 0.4855469,
      size.height * 0.4800781,
    );
    path_2.lineTo(size.width * 0.5556641, size.height * 0.4794922);
    path_2.lineTo(size.width * 0.5562500, size.height * 0.4412109);
    path_2.cubicTo(
      size.width * 0.5566406,
      size.height * 0.4058594,
      size.width * 0.5564453,
      size.height * 0.4027344,
      size.width * 0.5533203,
      size.height * 0.4021484,
    );
    path_2.cubicTo(
      size.width * 0.5513672,
      size.height * 0.4017578,
      size.width * 0.5183594,
      size.height * 0.4015625,
      size.width * 0.4800781,
      size.height * 0.4019531,
    );
    path_2.moveTo(size.width * 0.4250000, size.height * 0.6076172);
    path_2.cubicTo(
      size.width * 0.4222656,
      size.height * 0.6097656,
      size.width * 0.4199219,
      size.height * 0.6125000,
      size.width * 0.4199219,
      size.height * 0.6134766,
    );
    path_2.cubicTo(
      size.width * 0.4199219,
      size.height * 0.6166016,
      size.width * 0.4289062,
      size.height * 0.6154297,
      size.width * 0.4322266,
      size.height * 0.6117188,
    );
    path_2.cubicTo(
      size.width * 0.4394531,
      size.height * 0.6037109,
      size.width * 0.4339844,
      size.height * 0.6005859,
      size.width * 0.4250000,
      size.height * 0.6076172,
    );
    path_2.moveTo(size.width * 0.5679688, size.height * 0.6066406);
    path_2.cubicTo(
      size.width * 0.5617188,
      size.height * 0.6099609,
      size.width * 0.5607422,
      size.height * 0.6152344,
      size.width * 0.5662109,
      size.height * 0.6152344,
    );
    path_2.cubicTo(
      size.width * 0.5712891,
      size.height * 0.6152344,
      size.width * 0.5791016,
      size.height * 0.6085938,
      size.width * 0.5773438,
      size.height * 0.6058594,
    );
    path_2.cubicTo(
      size.width * 0.5755859,
      size.height * 0.6029297,
      size.width * 0.5744141,
      size.height * 0.6029297,
      size.width * 0.5679688,
      size.height * 0.6066406,
    );
    path_2.moveTo(size.width * 0.4199219, size.height * 0.7335938);
    path_2.lineTo(size.width * 0.4199219, size.height * 0.7523438);
    path_2.lineTo(size.width * 0.4345703, size.height * 0.7515625);
    path_2.cubicTo(
      size.width * 0.4472656,
      size.height * 0.7509766,
      size.width * 0.4498047,
      size.height * 0.7501953,
      size.width * 0.4544922,
      size.height * 0.7457031,
    );
    path_2.cubicTo(
      size.width * 0.4621094,
      size.height * 0.7378906,
      size.width * 0.4617187,
      size.height * 0.7279297,
      size.width * 0.4535156,
      size.height * 0.7205078,
    );
    path_2.cubicTo(
      size.width * 0.4478516,
      size.height * 0.7154297,
      size.width * 0.4458984,
      size.height * 0.7148438,
      size.width * 0.4335938,
      size.height * 0.7148438,
    );
    path_2.lineTo(size.width * 0.4199219, size.height * 0.7148438);
    path_2.close();
    path_2.moveTo(size.width * 0.5380859, size.height * 0.7171875);
    path_2.cubicTo(
      size.width * 0.5375000,
      size.height * 0.7187500,
      size.width * 0.5371094,
      size.height * 0.7269531,
      size.width * 0.5375000,
      size.height * 0.7355469,
    );
    path_2.lineTo(size.width * 0.5380859, size.height * 0.7509766);
    path_2.lineTo(size.width * 0.5496094, size.height * 0.7515625);
    path_2.cubicTo(
      size.width * 0.5636719,
      size.height * 0.7523437,
      size.width * 0.5714844,
      size.height * 0.7494141,
      size.width * 0.5751953,
      size.height * 0.7419922,
    );
    path_2.cubicTo(
      size.width * 0.5792969,
      size.height * 0.7341797,
      size.width * 0.5787109,
      size.height * 0.7275391,
      size.width * 0.5734375,
      size.height * 0.7212891,
    );
    path_2.cubicTo(
      size.width * 0.5693359,
      size.height * 0.7164062,
      size.width * 0.5673828,
      size.height * 0.7158203,
      size.width * 0.5539063,
      size.height * 0.7152344,
    );
    path_2.cubicTo(
      size.width * 0.5423828,
      size.height * 0.7146484,
      size.width * 0.5388672,
      size.height * 0.7150391,
      size.width * 0.5380859,
      size.height * 0.7171875,
    );

    // Paint paint_2_fill = Paint()..style=PaintingStyle.fill;
    // paint_2_fill.color = Color(0xff000000).withOpacity(1.0);
    // canvas.drawPath(path_2,paint_2_fill);

    path.addPath(path_0, Offset.zero);
    path.addPath(path_1, Offset.zero);
    path.addPath(path_2, Offset.zero);

    return path;
  }

  @override
  bool shouldRepaint(covariant LogoPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
