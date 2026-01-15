# Architecture (Frontend + Backend optionnel)

## Frontend iOS (SwiftUI) — Offline first

### Couches (Clean-ish / MVVM)
- **UI (SwiftUI Views)** : affichage + navigation + interaction
- **ViewModels (MVVM)** : état de l’écran, orchestration, validation réponses
- **Domain/Services** : `QuizEngine`, règles de sélection/shuffle, timer, scoring
- **Data** : `QuestionRepository` (local JSON), `StatsStore` (UserDefaults)

### Flux de données
- `HomeView` construit un `QuizConfig` → `QuizViewModel.start(config:)`
- `QuizViewModel` demande au repository la banque de questions → `QuizEngine` sélectionne/shuffle
- Les réponses de l’utilisateur génèrent un `QuizAttempt` → persisté via `StatsStore`

### Offline first
- Questions = JSON dans le bundle (fonctionne sans réseau)
- Stats = persistées en local (UserDefaults) et prêtes à être synchronisées (backend optionnel)

## Backend (optionnel)
Deux options :
1) **Firebase** : Auth + Firestore (rapidité + analytics)
2) **Node.js + MongoDB** : contrôle total + API REST + stats custom

Le frontend est prêt à supporter un repository distant via protocol (`QuestionRepository`),
sans dépendance tierce activée par défaut.


### Extensions
- Questions : support des **sous-catégories** (String) + **multi-réponses** (`correctIndices`).
- Import : CSV supporte `subcategory` et `answerIndex` multi (A|C / 0|2).
