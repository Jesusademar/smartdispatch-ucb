# SmartDispatch UCB

Aplicación Flutter para explicar y ejecutar la asignación óptima de técnicos de soporte en la UCB La Paz mediante el Método Húngaro.

## Qué incluye

- Simulador editable de matrices de 3 × 3 a 6 × 6.
- Optimización de tiempo (minimización) o idoneidad (maximización).
- Comparación inmediata entre una decisión voraz y el óptimo global.
- Reproductor visual de cada etapa del Método Húngaro.
- Grafo bipartito, matriz interactiva y plan de despacho con prioridades.
- Centro de despacho listo para operar: tickets, técnicos asignados, métricas y copia del plan al portapapeles.
- Diseño adaptable para escritorio y móviles.

## Ejecutar

```bash
flutter pub get
flutter run -d chrome
```

## Verificación

```bash
flutter analyze
flutter test
```

El caso UCB incluido obtiene **67 min** con el Método Húngaro frente a **94 min** con una asignación voraz.
