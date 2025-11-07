# User-Agent personnalisé pour Bug Bounty

## 📋 Vue d'ensemble

Certains programmes de bug bounty requièrent l'utilisation d'un User-Agent spécifique pour identifier les testeurs autorisés. Cette fonctionnalité permet de configurer un User-Agent personnalisé au niveau du projet.

## 🎯 Cas d'usage

Exemple de requirement typique dans un bug bounty :
```
"Please append to your user-agent header the following value: ' -BugBounty-memento-31337 '"
```

## ✅ Fonctionnalités

- ✅ Configuration du User-Agent lors de la création du projet
- ✅ Modification du User-Agent d'un projet existant
- ✅ Utilisation automatique dans tous les tests de vulnérabilités
- ✅ User-Agent par défaut si non configuré
- ✅ Stockage persistant en base de données

## 🚀 Utilisation

### 1. Lors de la création d'un projet (Interactif)

```bash
./leknight.sh
> project create
```

Le système vous demandera :
```
Bug Bounty User-Agent Configuration (Optional)
Some bug bounty programs require a specific User-Agent header.
Example: 'Mozilla/5.0 -BugBounty-memento-31337'
Leave empty for default User-Agent.

Custom User-Agent: Mozilla/5.0 (X11; Linux x86_64) -BugBounty-memento-31337
```

### 2. Lors de la création d'un projet (Programmatique)

```bash
./leknight.sh
> project create "My Bug Bounty" "HackerOne program" "example.com" "Mozilla/5.0 -BugBounty-memento-31337"
```

### 3. Modifier le User-Agent d'un projet existant

```bash
# Pour le projet courant
> project set-user-agent "Mozilla/5.0 -BugBounty-memento-31337"

# Pour un projet spécifique
> project set-user-agent 123 "Mozilla/5.0 -BugBounty-memento-31337"
```

### 4. Consulter le User-Agent configuré

```bash
# Pour le projet courant
> project get-user-agent

# Pour un projet spécifique
> project get-user-agent 123
```

### 5. Voir le User-Agent dans les métadonnées du projet

```bash
> project info
```

Le User-Agent sera affiché dans les informations du projet.

## 🔧 Implémentation technique

### Architecture

```
┌─────────────────────────────────────────┐
│         Projet (BDD SQLite)             │
│  ┌──────────────────────────────────┐   │
│  │ Champ: user_agent                │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│      core/http_helper.sh                │
│  ┌──────────────────────────────────┐   │
│  │ get_project_user_agent()         │   │
│  │ vuln_curl()                      │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│   Modules de tests de vulnérabilités   │
│  ┌──────────────────────────────────┐   │
│  │ XSS Module  → utilise vuln_curl  │   │
│  │ SQLi Module → utilise vuln_curl  │   │
│  │ CSRF Module → utilise vuln_curl  │   │
│  │ SSRF Module → utilise vuln_curl  │   │
│  │ CORS Module → utilise vuln_curl  │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Fonctions ajoutées

#### `core/database.sh`
- `db_get_user_agent(project_id)` - Récupère le User-Agent du projet
- `db_set_user_agent(project_id, user_agent)` - Configure le User-Agent
- `curl_with_project_ua(project_id, ...)` - Wrapper curl avec User-Agent

#### `core/http_helper.sh` (Nouveau)
- `get_project_user_agent(project_id)` - Helper pour récupérer le User-Agent
- `vuln_curl(project_id, ...)` - curl optimisé pour tests de vulns

#### `core/project.sh`
- `project_set_user_agent(project_id, user_agent)` - Command pour configurer
- `project_get_user_agent(project_id)` - Command pour consulter
- `project_create()` - Modifié pour accepter le User-Agent

### Schéma de base de données

```sql
ALTER TABLE projects ADD COLUMN user_agent TEXT;
```

## 📝 Exemples de User-Agent

### Bug Bounty platforms

```bash
# HackerOne
"Mozilla/5.0 (X11; Linux x86_64) -HackerOne-username"

# YesWeHack
"Mozilla/5.0 (X11; Linux x86_64) -YWH-hunter123"

# Bugcrowd
"Mozilla/5.0 (X11; Linux x86_64) -Bugcrowd-researcher"

# Intigriti
"Mozilla/5.0 (X11; Linux x86_64) -Intigriti-hunter"

# Custom
"Mozilla/5.0 (X11; Linux x86_64) -BugBounty-memento-31337"
```

### User-Agent par défaut

Si aucun User-Agent n'est configuré, le système utilise :
```
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36
```

## 🔍 Modules compatibles

Les modules suivants utilisent automatiquement le User-Agent du projet :

✅ **Tests d'injection**
- XSS (Reflected, Stored, DOM)
- SQL Injection
- XXE
- RCE
- LFI/RFI

✅ **Tests d'authentification**
- CSRF
- IDOR

✅ **Tests serveur**
- SSRF
- XSPA

✅ **Tests de configuration**
- CORS

✅ **Pipelines**
- Fuzzing (FFUF)
- DNS dump
- Vulnerability testing orchestrator

## 📊 Vérification

Pour vérifier que le User-Agent est bien utilisé, vous pouvez :

1. **Consulter les logs de scan** : Le User-Agent est inclus dans toutes les requêtes
2. **Utiliser un proxy** : Burp Suite ou OWASP ZAP pour intercepter les requêtes
3. **Consulter les logs serveur** : Vérifier côté cible

### Exemple avec Burp Suite

```bash
# Configurer le proxy
export HTTP_PROXY=http://127.0.0.1:8080
export HTTPS_PROXY=http://127.0.0.1:8080

# Lancer un scan
./leknight.sh
> autopilot start
```

Dans Burp Suite HTTP History, vous verrez :
```
GET /admin HTTP/1.1
Host: example.com
User-Agent: Mozilla/5.0 -BugBounty-memento-31337
```

## 🛠️ Migration de projets existants

Pour ajouter un User-Agent à un projet existant :

```bash
# 1. Charger le projet
> project load <id>

# 2. Configurer le User-Agent
> project set-user-agent "Mozilla/5.0 -BugBounty-memento-31337"

# 3. Vérifier
> project get-user-agent
```

## ⚠️ Notes importantes

1. **Guillemets** : Utilisez des guillemets pour préserver les espaces
   ```bash
   ✅ project set-user-agent "Mozilla/5.0 -BugBounty-test"
   ❌ project set-user-agent Mozilla/5.0 -BugBounty-test
   ```

2. **Caractères spéciaux** : Échappez si nécessaire
   ```bash
   project set-user-agent "Mozilla/5.0 'Researcher-123'"
   ```

3. **Longueur** : Pas de limite, mais restez raisonnable (< 500 caractères)

4. **Persistance** : Le User-Agent est stocké en base et survit aux redémarrages

## 🎓 Bonnes pratiques

1. **Toujours configurer pour les bug bounties** : Même si optionnel, c'est une bonne pratique
2. **Utiliser un identifiant unique** : Facilite le tracking côté programme
3. **Documenter** : Notez dans la description du projet le User-Agent utilisé
4. **Tester d'abord** : Vérifiez que le User-Agent est accepté avant de lancer l'autopilot
5. **Vérifier les règles** : Certains programmes ont des formats spécifiques

## 📞 Support

Pour toute question ou problème :
- Consultez la documentation : `ADVANCED_FEATURES.md`
- Vérifiez les logs : `data/logs/leknight.log`
- Utilisez `project info` pour vérifier la configuration

## 🔄 Compatibilité

- ✅ Compatible avec tous les workflows existants
- ✅ Rétrocompatible (User-Agent par défaut si non configuré)
- ✅ Compatible avec autopilot mode
- ✅ Compatible avec tous les outils (nmap, nuclei, etc.)

---

**Développé pour LeKnight Bash** 🛡️

*Framework de sécurité offensif pour tests d'intrusion professionnels*
