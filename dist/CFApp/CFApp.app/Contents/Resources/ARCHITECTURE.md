# Architecture (Frontend + Backend optionnel)

## Frontend SwiftUI (iOS + macOS)

### Couches (MVVM)
- UI (SwiftUI Views): affichage, navigation, interaction.
- ViewModels: etat ecran, orchestration de flux, logique de quiz.
- Services/Domain: `QuizEngine`, SRS, import/export, backup, cache image.
- Data: repositories JSON locaux + stores persistants (UserDefaults / disque).

### Flux principal
- `HomeView` compose un `QuizConfig` puis lance `QuizViewModel.start(config:)`.
- `QuizViewModel` charge les questions via repository et prepare le set avec `QuizEngine`.
- Les reponses utilisateur produisent un `QuizAttempt` persiste via `StatsStore`.
- L'historique question (`QuestionHistoryStore`) alimente la priorisation SRS.

### Offline first
- Questions/formules embarquees en JSON.
- Import ZIP/CSV local pour enrichir la base.
- Stores locaux versionnes avec migration retrocompatible.
- Backup/restauration globale JSON de l'etat applicatif.

### macOS ergonomie
- Cible macOS active sur le target principal.
- Raccourcis clavier dans quiz/formules.
- Commandes de menu macOS (navigation + ouverture import ZIP).
- Drag-and-drop ZIP/CSV dans l'ecran d'import.

### Qualite
- CI GitHub Actions: build + tests unitaires macOS et iOS Simulator.
- Tests: moteur quiz, priorisation SRS, migration store, round-trip backup.

## Backend (optionnel)
- Repository distant possible via protocoles (sans dependance active par defaut).
- Le mode actuel reste full offline avec architecture prete a synchronisation ulterieure.
