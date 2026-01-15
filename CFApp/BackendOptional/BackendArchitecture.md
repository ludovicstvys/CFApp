# Backend optionnel : architecture proposée

L’app fonctionne **100% offline**. Ce document décrit une option backend pour :
- comptes utilisateurs
- sauvegarde/synchro des scores
- statistiques avancées
- banque de questions centralisée + mises à jour

## Option A — Firebase (simple & rapide)
### Services
- **Firebase Auth** (Email/Password, Sign in with Apple)
- **Cloud Firestore**
- (optionnel) **Cloud Functions** pour agrégations / anti-triche

### Modèle de données (Firestore)
- `users/{uid}`
  - `createdAt`, `displayName`, `levelTarget`, `settings`
- `users/{uid}/attempts/{attemptId}`
  - `date`, `level`, `mode`, `categories[]`, `score`, `total`, `durationSeconds`
  - `perCategory` (map)
- `questions/{questionId}`
  - `level`, `category`, `stem`, `choices[]`, `answerIndex`, `explanation`, `difficulty`

### Règles
- chaque utilisateur lit/écrit uniquement ses documents `users/{uid}/...`
- `questions` en lecture publique (ou sous abonnement)

## Option B — Node.js + MongoDB (contrôle total)
### Stack
- Node.js + Express
- MongoDB (Atlas)
- JWT (access token + refresh token)
- Rate limiting + validation (zod/joi)

### Endpoints (REST)
- `POST /auth/register`
- `POST /auth/login`
- `GET /questions?level=1&category=Ethics&limit=60`
- `POST /attempts` (enregistrer un quiz)
- `GET /stats/summary` (agrégats par catégorie, tendance, etc.)

### Collections
- `users`
- `attempts`
- `questions`

## Intégration iOS (sans package tiers par défaut)
- `RemoteAPI` (URLSession) + `RemoteQuestionRepository`
- stratégie : Sync “pull” des questions + “push” attempts
- fallback offline : si erreur réseau → dataset local + stats locales

⚠️ Pour Firebase, il faut ajouter le SDK (Swift Package Manager) — c’est la seule dépendance “justifiée”.
