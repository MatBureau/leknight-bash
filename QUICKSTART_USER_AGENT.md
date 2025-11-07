# Quick Start - User-Agent personnalisé

## 🚀 Guide de démarrage rapide (5 minutes)

### Étape 1 : Migration de la base (si existante)

```bash
bash scripts/migrate_user_agent.sh
```

**Résultat attendu** :
```
===================================
LeKnight Database Migration
Adding User-Agent support
===================================

✅ Migration successful!
```

### Étape 2 : Créer un projet avec User-Agent

```bash
./leknight.sh
```

Puis dans l'interface :

```
> project create
```

**Interaction** :
```
========================================
CREATE NEW PROJECT
========================================

Project Name: HackerOne Target XYZ
Description: Bug bounty program for example.com
Define project scope (press Enter on empty line to finish):
Examples: example.com, *.example.com, 192.168.1.0/24

Scope entry: example.com
Scope entry: *.example.com
Scope entry:

Bug Bounty User-Agent Configuration (Optional)
Some bug bounty programs require a specific User-Agent header.
Example: 'Mozilla/5.0 -BugBounty-memento-31337'
Leave empty for default User-Agent.

Custom User-Agent: Mozilla/5.0 (X11; Linux x86_64) -BugBounty-memento-31337

Create project 'HackerOne Target XYZ'? [Y/n]: y
✅ Project created with ID: 1
✅ Custom User-Agent configured: Mozilla/5.0 (X11; Linux x86_64) -BugBounty-memento-31337
✅ Project 'HackerOne Target XYZ' is now active
```

### Étape 3 : Vérifier la configuration

```
> project info
```

**Résultat** :
```
╔════════════════════════════════════════════════════════╗
  PROJECT INFORMATION
╚════════════════════════════════════════════════════════╝

ID: 1
Name: HackerOne Target XYZ
Description: Bug bounty program for example.com
Scope: example.com
       *.example.com
User-Agent: Mozilla/5.0 (X11; Linux x86_64) -BugBounty-memento-31337
Status: active
Created: 2024-11-07 13:30:00
```

### Étape 4 : Lancer un scan

```
> autopilot start
```

**Le système utilisera automatiquement votre User-Agent personnalisé** dans tous les tests :
- XSS
- SQL Injection
- CSRF
- SSRF
- CORS
- Fuzzing
- DNS dump
- Etc.

### Étape 5 : Modifier le User-Agent (optionnel)

Si vous devez changer le User-Agent plus tard :

```
> project set-user-agent "Mozilla/5.0 (X11; Linux x86_64) -NewIdentifier"
```

## 📋 Exemples de User-Agent par plateforme

### HackerOne
```
Mozilla/5.0 (X11; Linux x86_64) -H1-username
```

### YesWeHack
```
Mozilla/5.0 (X11; Linux x86_64) -YWH-hunter123
```

### Bugcrowd
```
Mozilla/5.0 (X11; Linux x86_64) -BC-researcher
```

### Intigriti
```
Mozilla/5.0 (X11; Linux x86_64) -ITG-hunter
```

### Custom Bug Bounty
```
Mozilla/5.0 (X11; Linux x86_64) -BugBounty-memento-31337
```

## ✅ Vérification

Pour vérifier que ça fonctionne, utilisez Burp Suite :

```bash
# Terminal 1 : Démarrer Burp Suite
# Configurer le proxy sur 127.0.0.1:8080

# Terminal 2 : Configurer le proxy
export HTTP_PROXY=http://127.0.0.1:8080
export HTTPS_PROXY=http://127.0.0.1:8080

# Terminal 2 : Lancer LeKnight
./leknight.sh
> autopilot start
```

Dans Burp Suite, HTTP History :
```http
GET /admin HTTP/1.1
Host: example.com
User-Agent: Mozilla/5.0 (X11; Linux x86_64) -BugBounty-memento-31337
Accept: */*
```

✅ **Votre User-Agent personnalisé est utilisé !**

## 🎯 Cas d'usage complet

```bash
# 1. Lancer LeKnight
./leknight.sh

# 2. Créer projet avec User-Agent
> project create "BB Target" "HackerOne" "target.com" "Mozilla/5.0 -H1-myusername"

# 3. Ajouter des cibles au scope
> project scope add "*.target.com"
> project scope add "api.target.com"

# 4. Lancer l'autopilot
> autopilot start

# 5. Surveiller les résultats
> dashboard

# 6. Consulter les findings
> findings list

# 7. Exporter le rapport
> report generate markdown
```

**Toutes les requêtes utiliseront votre User-Agent personnalisé !**

## ⚠️ Points importants

1. **Guillemets obligatoires** : Toujours utiliser des guillemets pour le User-Agent
   ```bash
   ✅ "Mozilla/5.0 -BugBounty-test"
   ❌ Mozilla/5.0 -BugBounty-test
   ```

2. **Vérifier les règles** : Consultez les règles du programme avant de scanner

3. **Identifier unique** : Utilisez un identifiant unique pour faciliter le tracking

4. **Test préalable** : Testez avec un simple curl avant de lancer l'autopilot
   ```bash
   curl -A "Mozilla/5.0 -BugBounty-test" https://target.com
   ```

## 🔧 Dépannage

### Le User-Agent n'est pas utilisé
```bash
# Vérifier la configuration
> project get-user-agent

# Vérifier les métadonnées
> project info

# Reconfigurer si nécessaire
> project set-user-agent "Nouveau User-Agent"
```

### Migration échoue
```bash
# Sauvegarder la base
cp data/db/leknight.db data/db/leknight.db.backup

# Réessayer la migration
bash scripts/migrate_user_agent.sh

# Si ça échoue, contactez le support
```

### User-Agent trop long
```bash
# Limiter à ~200 caractères
# Si plus long, peut causer des problèmes avec certains serveurs
```

## 📚 Documentation complète

Pour plus de détails :
- **Guide complet** : `USER_AGENT_FEATURE.md`
- **Changelog** : `CHANGELOG_USER_AGENT.md`
- **Features avancées** : `ADVANCED_FEATURES.md`

## 💡 Astuce

Créez des alias pour vos plateformes favorites :

```bash
# ~/.bashrc ou ~/.zshrc
alias lk-h1="./leknight.sh -ua 'Mozilla/5.0 -H1-username'"
alias lk-ywh="./leknight.sh -ua 'Mozilla/5.0 -YWH-hunter123'"
alias lk-bc="./leknight.sh -ua 'Mozilla/5.0 -BC-researcher'"
```

---

**C'est tout ! Vous êtes prêt à utiliser LeKnight avec vos programmes de bug bounty ! 🎉**
