# Corruption Risk Prediction — Flutter App

A Flutter front-end for the Control-of-Corruption (`cce`) regression model built in
`wgi_corruption_regression_analysis.ipynb`.

## Project structure

```
lib/
  main.dart          -> App entry point + theme (colors, cards, inputs match the mockup)
  screen.dart         -> The single prediction screen (form, Predict/Clear, result panel)
  api_service.dart    -> HTTP client with PLACEHOLDER endpoint values
pubspec.yaml          -> Dependencies (flutter, http)
```

## Input fields

The form has exactly the **10 real predictors** the model was trained on:

Estimates: `vae`, `pve`, `gee`, `rqe`, `rle`
Standard errors: `vas`, `pvs`, `ges`, `rqs`, `rls`

`cce` (Control of Corruption — Estimate) is **not** an input — it's the value the model
predicts, shown in the result panel after tapping **Predict**.

## Wiring up your API

Once you deploy the model (e.g. as a Flask/FastAPI endpoint wrapping `model.pkl` +
`scaler.pkl`), open `lib/api_service.dart` and replace the two placeholders:

```dart
static const String baseUrl = "https://REPLACE_WITH_YOUR_API_URL";
static const String predictPath = "/PATH_TO_PREDICT";
```

The app POSTs a JSON body shaped like:

```json
{
  "vae": 0.84, "pve": 1.12, "gee": 1.45, "rqe": 0.98, "rle": 1.21,
  "vas": 0.12, "pvs": 0.15, "ges": 0.11, "rqs": 0.14, "rls": 0.13
}
```

and expects a JSON response shaped like:

```json
{ "cce_prediction": 0.732 }
```

If your backend returns a different key name, update the `data['cce_prediction']` line
inside `ApiService.predictCorruption`.

## Running the app

```bash
flutter pub get
flutter run
```

## Validation rules

- All 10 fields are required.
- Estimate fields (`vae`, `pve`, `gee`, `rqe`, `rle`) accept values between -3.0 and 3.0
  (real WGI estimates typically fall between -2.5 and 2.5).
- Standard-error fields (`vas`, `pvs`, `ges`, `rqs`, `rls`) accept values between 0.0 and 1.5.
- Missing or out-of-range values are flagged inline under each field, and a summary error
  also appears in the result panel — the same panel used to show a successful prediction.

## Clear button

Available both in the AppBar and next to the Predict button — resets every field and
returns the result panel to its initial "Ready for Analysis" state.
