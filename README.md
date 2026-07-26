# Control of Corruption Predictor

## Mission

Corruption is one of the clearest threats to a country's institutional health — it weakens public trust, discourages investment, and undermines the rule of law that everything else depends on. This project's mission is to estimate a country's **Control of Corruption** score (`cce`, roughly −2.5 to +2.5; higher = stronger control of corruption) from five other governance dimensions — Voice & Accountability, Political Stability, Government Effectiveness, Regulatory Quality, and Rule of Law — across **212 countries and territories, 1996–2021**.

This is country-level regression, not a fraud-detection or individual-risk tool: it identifies which governance dimensions move together with strong (or weak) corruption control, and estimates where a country's institutional profile places it, to support comparative governance analysis and policy prioritization.

## Dataset

- **4,922 raw country-year observations → 4,876 after cleaning**, across 212 countries, 1996–2021, using 10 governance-indicator features
- **4 regression models compared:** OLS, SGD (gradient descent), Decision Tree, Random Forest
- **Random Forest selected** — Test R² = **95.63%**, Test RMSE = **0.203**, Test MAE = **0.144**
- **Rule of Law and Government Effectiveness** carry by far the most predictive weight — confirmed independently by correlation analysis, OLS coefficients, and Random Forest feature importances
- Flutter mobile app built as the prediction front-end; a FastAPI backend is the planned next step (see [API](#api))

## Data Source

The dataset is the **World Bank Worldwide Governance Indicators (WGI)**, obtained as a pre-assembled snapshot via Kaggle rather than pulled from the live API directly in this pipeline.

| Source | Link |
|---|---|
| Kaggle dataset used in this project: 1996, 1998, 2000, then annually 2002–2021 | https://www.kaggle.com/datasets/cvengr/government-corruption-data-of-180-countries | 
| Official WGI data & documentation (primary source): Annually updated; the live WGI series has since been extended through 2024 | https://www.govindicators.org and https://www.worldbank.org/en/publication/worldwide-governance-indicators | 
| World Bank DataBank interface: Interactive query/download tool for the same underlying data | https://databank.worldbank.org/source/worldwide-governance-indicators | 

**Note on recency:** the Kaggle snapshot used here ends in 2021. The World Bank's live WGI release now covers through 2024 and underwent a **2025 methodology revision** (a stricter source-screening protocol and a new absolute 0–100 scale alongside the original standardized estimate). A future update of this project could re-pull directly from `www.govindicators.org` or the World Bank API to bring the training data current — see [Planned Enhancements](#planned-enhancements).

### WGI columns used

The WGI publishes six governance dimensions, each with six sub-fields (estimate, standard error, number of sources, percentile rank, and 90% confidence-interval lower/upper bounds). This project uses the **estimate** and **standard error** sub-fields from five dimensions as features, and the **estimate** sub-field of the sixth as the target:

| Column | Feature name | Description |
|---|---|---|
| `vae` | Voice & Accountability — estimate | Citizens' ability to participate in selecting government, freedom of expression/association, free media |
| `vas` | Voice & Accountability — standard error | Statistical uncertainty of `vae` |
| `pve` | Political Stability — estimate | Likelihood of political instability or politically-motivated violence (incl. terrorism) |
| `pvs` | Political Stability — standard error | Statistical uncertainty of `pve` |
| `gee` | Government Effectiveness — estimate | Quality of public services, civil service, policy formulation/implementation |
| `ges` | Government Effectiveness — standard error | Statistical uncertainty of `gee` |
| `rqe` | Regulatory Quality — estimate | Government's ability to formulate/implement sound private-sector policy |
| `rqs` | Regulatory Quality — standard error | Statistical uncertainty of `rqe` |
| `rle` | Rule of Law — estimate | Confidence in contract enforcement, property rights, police, courts |
| `rls` | Rule of Law — standard error | Statistical uncertainty of `rle` |
| `cce` | **Control of Corruption — estimate (target)** | Extent to which public power is exercised for private gain |

All other WGI sub-fields (`*n` number of sources, `*r` percentile rank, `*l`/`*u` confidence bounds, and every `cc*` field other than `cce` itself) were excluded — the rank/CI columns are direct transformations of their own estimate column, and including the other `cc*` fields alongside the `cce` target would be data leakage.

## How the Data Was Cleaned and Prepared

1. **Load** — the Kaggle CSV is read directly as a single wide table (`code`, `countryname`, `year`, plus all 36 WGI sub-field columns); unlike a two-source merge, no join was required here.
2. **Missing-value audit** — every governance column had a real, non-trivial gap: `gee`/`ges` and the rest of the Government Effectiveness family were ~4.94% missing, `rqe`/`rqs` ~4.90%, `cce` ~4.45%, `pve`/`pvs` ~3.43%, and `rle`/`rls` ~2.62% — consistent with the WGI's own irregular pre-2002 reporting schedule (only 1996, 1998, and 2000 were published before annual reporting began).
3. **Fill-strategy comparison** — on `rls` (Rule of Law standard error, ~2.62% missing), a global mean fill was tested against **within-country linear interpolation**. The global mean fill compressed `rls`'s natural variance and pulled its correlation with `cce` slightly toward zero; interpolation preserved both far better — the same conclusion reached when comparing these two strategies on health/economic panel data elsewhere, and the reason interpolation was adopted for every column here.
4. **Missing-by-country check** — **Monaco and San Marino had 100% missing `cce`, `gee`, and `rqe` across every one of the 23 years on record.** The World Bank has never published these estimates for either micro-state, so interpolation had nothing to work from; both countries were excluded, leaving 212 countries.
5. **Apply interpolation** — within-country linear interpolation was applied to all 10 feature columns and the target across the remaining 212 countries.
6. **Multicollinearity check (VIF)** — before finalizing the feature set:

   | Feature | VIF |
   |---|---|
   | `gee` | 11.48 |
   | `rle` | 11.21 |
   | `rqe` | 9.40 |
   | `rls` | 7.07 |
   | `ges` | 4.33 |
   | `rqs` | 4.12 |
   | `vas` | 3.55 |
   | `vae` | 3.39 |
   | `pve` | 2.97 |
   | `pvs` | 2.93 |

   `gee`, `rle`, and `rqe` show moderate overlap (governance dimensions genuinely move together in real countries), but none reach the severe multicollinearity range, and VIF thresholds like "10" are themselves a debated rule of thumb rather than a hard cutoff (O'Brien, 2007) — so all 10 requested predictors were kept.
7. **Drop identifiers** — `code` and `countryname` (row identifiers, no governance signal) were dropped; `year` and the remaining unused WGI sub-fields were retained in the cleaned file for reference but excluded from the model inputs.
8. **Output** — 4,876 cleaned rows across 37 columns, split 80/20 into 3,900 train / 976 test rows.

## Model Background & Performance

Four regression approaches were trained and compared: Ordinary Least Squares, SGD (manual gradient-descent loop with an explicit train/test loss curve tracked epoch-by-epoch), a depth-tuned Decision Tree, and a Random Forest.

| | OLS | SGD | Decision Tree | Random Forest |
|---|---|---|---|---|
| Train RMSE | 0.326 | 0.327 | 0.073 | 0.076 |
| Test RMSE | 0.319 | 0.319 | 0.261 | **0.203** |
| Train MAE | 0.263 | 0.263 | 0.034 | 0.054 |
| Test MAE | 0.254 | 0.254 | 0.175 | **0.144** |
| Train R² | 89.17% | 89.17% | 99.46% | 99.41% |
| Test R² | 89.24% | 89.26% | 92.78% | **95.63%** |

**Random Forest was selected** — it posted the best score on every test-set metric (RMSE, MAE, and R²), with no trade-off to weigh. OLS and SGD converge to essentially the same linear solution (as expected — SGD is just an iterative way of solving the same regression problem OLS solves in closed form), capturing ~89% of the variance. Random Forest's edge over the single Decision Tree comes from averaging across many trees, which tempers the Decision Tree's overfitting (note its much larger Train/Test R² gap) while still capturing the slight non-linear curvature in how governance dimensions relate to each other.

### Which features carry the most weight

Three independent methods agree on the same answer:

| Method | Top feature | 2nd | 3rd |
|---|---|---|---|
| Correlation with `cce` | `rle` (r = 0.936) | `gee` (r = 0.919) | `rqe` (r = 0.867) |
| OLS standardized coefficient | `rle` (0.527) | `gee` (0.431) | `rqe` (−0.092) |
| Random Forest feature importance | `rle` (0.794) | `gee` (0.117) | `vae` (0.022) |

**Rule of Law and Government Effectiveness dominate the prediction** in every method tried; the five standard-error columns (`vas`, `pvs`, `ges`, `rqs`, `rls`) consistently contribute the least, since they measure the *precision* of an estimate rather than governance quality itself.

## Evaluation Scope

The model is designed to estimate a country's Control of Corruption level from its *current* governance profile in a given year — not to forecast a country's future corruption trajectory. Accordingly, an 80/20 **random** train-test split was used across country-year observations rather than a temporal split. This evaluates the model's ability to generalize to unseen country-year combinations among the 212 countries studied, not its ability to forecast future years or generalize to a country it has never seen at all.


### Recommended CORS configuration (once deployed)

```
allow_origins=["http://localhost:3000", "http://127.0.0.1:3000"]  # add your web dev origin(s) if you build one
allow_credentials=False
allow_methods=["GET", "POST"]
allow_headers=["Content-Type"]
```
Reasoning: methods limited to GET/POST since the API only reads status and predicts; credentials disabled since this is a stateless prediction API with no session/cookie auth; the Flutter mobile app is not subject to CORS at all, since CORS only restricts browser-based requests.

## Model Comparison

Trained and evaluated in
[`summative/linear_regression/wgi_corruption_linear_regression.ipynb`](summative/linear_regression/wgi_corruption_linear_regression.ipynb):

| Model | Train RMSE | Test RMSE | Train MAE | Test MAE | Train R² | Test R² |
|---|---|---|---|---|---|---|
| OLS Linear Regression | 0.326 | 0.319 | 0.263 | 0.254 | 89.17% | 89.24% |
| SGD Regressor (gradient descent) | 0.327 | 0.319 | 0.263 | 0.254 | 89.17% | 89.26% |
| Decision Tree | 0.073 | 0.261 | 0.034 | 0.175 | 99.46% | 92.78% |
| **Random Forest (best)** | 0.076 | **0.203** | 0.054 | **0.144** | 99.41% | **95.63%** |

**Random Forest** was saved as the production model (`model.pkl` / `scaler.pkl`) — lowest test RMSE
and highest test R² of the four, and its train/test gap is far smaller than the single Decision
Tree's, meaning it generalizes rather than memorizing. The two linear models (OLS, SGD) land within
noise of each other, confirming gradient descent converged to essentially the same optimum as the
closed-form solution; both are ~6 points of R² behind Random Forest because the `rle`/`cce`
relationship has mild curvature a straight line can't capture.


## Repository Structure

```
corruption_prediction/
├── README.md
├── requirements.txt
├── summative/
│   ├── linear_regression/
│   │   ├── wgi_corruption_regression_analysis.ipynb   # full notebook: EDA, cleaning, VIF, training, comparison
│   │   ├── wgidataset.csv                             # raw Kaggle/WGI snapshot
│   │   ├── wgi_corruption_train_data.csv               # the 80% train split used to fit every model
│   │   ├── wgi_corruption_test_data.csv                # the 20% held-out test split
│   │   └── model.pkl, scaler.pkl                       # saved best-performing model (Random Forest) + fitted scaler
│   │
│   ├── api/                      # PLANNED — FastAPI backend, not yet implemented
│   │
│   └── FlutterApp/          # the Flutter mobile app
│       ├── lib/
│       │   ├── main.dart         # app entry point + theme
│       │   ├── screen.dart       # the single prediction screen (form, Predict/Clear, result panel)
│       │   └── api_service.dart  # HTTP client — placeholder endpoint, update once the API is deployed
│       └── pubspec.yaml
```

## Setup (uv)

From the repo root:

```bash
uv sync
```

Or with plain pip: `pip install -r requirements.txt`.

## Running the API locally

```bash
uv run uvicorn api.main:app --app-dir summative --reload
```

Then open **http://127.0.0.1:8000/docs** for the local Swagger UI.

## Public API (deployed)

- **Base URL:** https://regression-analysis-mobile-application-om0i.onrender.com
- **Swagger UI:** https://regression-analysis-mobile-application-om0i.onrender.com/docs

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Liveness check |
| POST | `/predict` | Predicts `cce` from the 10 WGI features |
| POST | `/retrain` | Uploads a CSV of new labelled rows, retrains in the background |
| GET | `/retrain/{job_id}` | Polls the status/metrics of a retraining job |

`POST /predict` takes all 10 predictors as required, range-validated floats (Pydantic `Field(ge=..., le=...)`):
`vae`, `vas`, `pve`, `pvs`, `gee`, `ges`, `rqe`, `rqs`, `rle`, `rls` (estimate columns: −3.5 to 3.5;
standard-error columns: 0.0 to 1.5 — bounds derived from the real training-data range with headroom).
Out-of-range or missing values are rejected with `422` before reaching the model. Response:

```json
{ "control_of_corruption": 0.4256, "model_name": "Random Forest Regressor" }
```

`POST /retrain` accepts a multipart CSV upload (field name `file`, same columns as the predictors
plus `cce`), merges it with the existing training data, and re-fits `StandardScaler` +
`RandomForestRegressor` as a **FastAPI `BackgroundTask`** — the request returns a `202` and a
`job_id` immediately; poll `GET /retrain/{job_id}` for `queued` → `running` → `completed`/`failed`
and the resulting metrics. Once `completed`, `/predict` is already serving the retrained model.

### CORS

Configured in `summative/api/main.py` via `CORSMiddleware`, with `allow_credentials=False` (this
API has no cookies/session auth), `allow_methods=["GET", "POST"]` (only the verbs the API exposes),
and `allow_headers=["Content-Type", "Authorization"]` (`Content-Type` for JSON/multipart bodies,
`Authorization` reserved for future token auth on `/retrain`).

## Mobile App

Flutter single-screen app in `summative/FlutterApp/`: 10 input fields (one per WGI predictor,
grouped as estimates + standard errors), a **Predict** button, and a result panel that shows the
predicted `cce` or a validation/network error. It calls the deployed API above via
`summative/FlutterApp/lib/api_service.dart`.

To run it:

```bash
cd summative/FlutterApp
flutter pub get
flutter run          # pick a connected physical device or emulator when prompted
```

(Grading requires the **mobile** app, not the Flutter web target — run on an Android/iOS
device or emulator, e.g. `flutter run -d <device-id>` from `flutter devices`.)


## Planned Enhancements

- **Build and deploy the FastAPI backend** wrapping `model.pkl`/`scaler.pkl`, matching the request/response shape already expected by the Flutter app
- **SHAP explanations** attached to each prediction, so a returned `cce` estimate comes with a per-feature contribution breakdown
- **A retraining endpoint** to update the live model as new WGI releases become available, without a full redeploy
- **Refresh the training data** directly from the live WGI/World Bank source to extend coverage from 2021 through the current release year
- **A video walkthrough** of the notebook, app, and (once built) the API

## Limitations

- **Association, not causation** — the relationships the model learns are correlational. They do not establish that improving one governance dimension, such as Regulatory Quality, would causally improve Control of Corruption.
- **Random split, not a test of unseen countries** — the 80/20 split evaluates generalization across country-year observations, not the model's ability to generalize to a country it has never seen at all.
- **Interpolation introduces uncertainty** — values filled by within-country linear interpolation are estimates, not directly observed data points, and carry some uncertainty accordingly.
- **Perception-based data** — the WGI itself is built from surveys and expert assessments, not objective administrative records; every `cce` value (and every predictor) already carries its own margin of error, which is exactly what the standard-error columns in this dataset represent.
- **Dataset recency** — this project's snapshot ends in 2021; the live WGI series and its underlying methodology have since been updated (see [Data Source](#data-source)).
- **Not yet deployed** — there is no live prediction API at the time of writing; the Flutter app is functional as a UI but cannot return real predictions until the backend exists.
- **A decision-support and educational tool, not a policy verdict** — intended to help compare a country's institutional profile against governance patterns seen elsewhere, not to replace expert governance or anti-corruption analysis.

## Sources

### Data Sources
- Kaggle snapshot used in this project: https://www.kaggle.com/datasets/cvengr/government-corruption-data-of-180-countries
- World Bank Worldwide Governance Indicators (official, live source): https://www.govindicators.org
- WGI documentation: https://www.worldbank.org/en/publication/worldwide-governance-indicators/documentation
- WGI via World Bank DataBank: https://databank.worldbank.org/source/worldwide-governance-indicators

### References
- Kaufmann, D., Kraay, A., & Mastruzzi, M. (2010). *The Worldwide Governance Indicators: Methodology and Analytical Issues.* World Bank Policy Research Working Paper No. 5430. https://ssrn.com/abstract=1682130 — the foundational methodology this entire dataset is built on.
- Kaufmann, D., & Kraay, A. (2024). *The Worldwide Governance Indicators: Methodology and 2024 Update.* World Bank Policy Research Working Paper No. 10952. https://openknowledge.worldbank.org/bitstreams/64afd13e-e4e5-409e-9ef1-958b0b723f75/download — the most recent update to the methodology summarized above.
- O'Brien, R. M. (2007). *A Caution Regarding Rules of Thumb for Variance Inflation Factors.* Quality & Quantity, 41, 673–690. https://doi.org/10.1007/s11135-006-9018-6 — basis for treating VIF ≈ 9–13 as moderate rather than automatically disqualifying, since commonly-cited thresholds like "10" are a convention rather than a hard statistical cutoff.
- Noor, N. M., Abdullah, M. M. A. B., Yahaya, A. S., & Ramli, N. A. (2014). *Comparison of Linear Interpolation Method and Mean Method to Replace the Missing Values in Environmental Data Set.* Materials Science Forum, 803, 278–281. https://www.researchgate.net/publication/271978892 — direct precedent for comparing linear interpolation against a global mean fill, the same comparison used in this project's cleaning step.

### Documentation
- scikit-learn: https://scikit-learn.org/stable/
- statsmodels (VIF): https://www.statsmodels.org/stable/index.html
- Flutter: https://docs.flutter.dev/
- FastAPI (planned backend): https://fastapi.tiangolo.com/

## Author

Maurice Nshimyumukiza

Email: m.nshimyumu@alustudent.com

GitHub: N.Maurice

## Paths and Links

- Notebook: `summative/linear_regression/wgi_corruption_regression_analysis.ipynb`
- Mobile app: `summative/FlutterApp/`
- Backend API: `summative/api/`
- Video demo: 
