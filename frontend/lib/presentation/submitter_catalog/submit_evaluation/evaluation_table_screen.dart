import '../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../navigation_history.dart';
import 'submit_evaluation_provider.dart';
import 'submit_evaluation_state.dart';
import 'submit_evaluation_api.dart';

class EvaluationsTableScreen extends StatefulWidget {
  const EvaluationsTableScreen({super.key});

  @override
  State<EvaluationsTableScreen> createState() => _EvaluationsTableScreenState();
}

class _EvaluationsTableScreenState extends State<EvaluationsTableScreen> {
  late Future<List<Grading>> obtainedGradings;
  final _provider = SubmitEvaluationProvider(SubmitEvaluationApi());

  @override
  void initState() {
    super.initState();
    obtainedGradings = _provider.getGradings();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Grading>>(
        future: obtainedGradings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Text(snapshot.error.toString());
          }

          final gradings = snapshot.data!;

          return Scaffold(
              body: Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                        AppColors.backgroundDark,
                        AppColors.surfaceDark2
                      ])),
                  child: SafeArea(
                      child: Center(
                          child: Padding(
                              padding: EdgeInsets.all(24),
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 1200),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _Header(
                                        onNewEvaluation: () => context
                                            .pushNamed('submit_evaluation'),
                                        onBack: () {
                                          goBackOrHome(context);
                                        },
                                      ),
                                      const SizedBox(
                                        height: 24,
                                      ),
                                      Expanded(
                                        child: _TableCard(
                                            child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: DataTable(
                                                  columns: const [
                                                    DataColumn(
                                                        label: Text('ID')),
                                                    DataColumn(
                                                        label: Text(
                                                            'Fecha de solicitud')),
                                                    DataColumn(
                                                        label: Text('Estado')),
                                                    DataColumn(
                                                        label: Text(
                                                            'Grado de centro')),
                                                    DataColumn(
                                                        label: Text(
                                                            'Grado de bordes')),
                                                    DataColumn(
                                                        label: Text(
                                                            'Grado de esquinas')),
                                                    DataColumn(
                                                        label: Text(
                                                            'Grado de superficie')),
                                                    DataColumn(
                                                        label: Text(
                                                            'Grado final')),
                                                    DataColumn(
                                                        label:
                                                            Text('Confianza')),
                                                    DataColumn(
                                                        label: Text(
                                                            'Fecha de evaluacion')),
                                                  ],
                                                  rows: gradings.map((grade) {
                                                    return DataRow(cells: [
                                                      DataCell(Text(grade
                                                          .gradeId
                                                          .toString())),
                                                      DataCell(Text(
                                                          grade.submittedDate)),
                                                      DataCell(
                                                          Text(grade.status)),
                                                      DataCell(Text(grade
                                                              .centering_grade
                                                              ?.toString() ??
                                                          'No ha sido evaluado')),
                                                      DataCell(Text(grade
                                                              .edges_grade
                                                              ?.toString() ??
                                                          'No ha sido evaluado')),
                                                      DataCell(Text(grade
                                                              .corners_grade
                                                              ?.toString() ??
                                                          'No ha sido evaluado')),
                                                      DataCell(Text(grade
                                                              .surface_grade
                                                              ?.toString() ??
                                                          'No ha sido evaluado')),
                                                      DataCell(Text(grade.grade
                                                              ?.toString() ??
                                                          'No ha sido evaluado')),
                                                      DataCell(Text(grade
                                                              .confidence
                                                              ?.toString() ??
                                                          'No ha sido evaluado')),
                                                      DataCell(Text(grade
                                                              .gradedDate ??
                                                          'No ha sido evaluado'))
                                                    ]);
                                                  }).toList(),
                                                ))),
                                      )
                                    ],
                                  )))))));
        });
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onNewEvaluation;
  final VoidCallback onBack;

  const _Header({required this.onNewEvaluation, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mis evaluaciones',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Consulta el estado de tus evaluaciones.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: onNewEvaluation,
          icon: const Icon(Icons.add),
          label: const Text('Nueva evaluación'),
        ),
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Volver'),
        ),
      ],
    );
  }
}

class _TableCard extends StatelessWidget {
  final Widget child;

  const _TableCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.borderDark,
        ),
      ),
      child: child,
    );
  }
}
