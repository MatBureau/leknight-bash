# Changelog - User-Agent personnalisé pour Bug Bounty

## Version 2.1.0 - Support User-Agent personnalisé

### 🎯 Nouvelle fonctionnalité

Ajout du support pour User-Agent personnalisé au niveau du projet, permettant de se conformer aux exigences des programmes de bug bounty.

### ✨ Modifications apportées

#### 1. Base de données
**Fichier** : `core/database.sh`
- ✅ Ajout de la colonne `user_agent` dans la table `projects`
- ✅ Fonction `db_get_user_agent(project_id)` - Récupère le User-Agent
- ✅ Fonction `db_set_user_agent(project_id, user_agent)` - Configure le User-Agent
- ✅ Fonction `curl_with_project_ua(project_id, ...)` - Wrapper curl avec User-Agent

**Schéma SQL** :
```sql
ALTER TABLE projects ADD COLUMN user_agent TEXT;
```

#### 2. Gestion de projet
**Fichier** : `core/project.sh`
- ✅ `project_create()` - Accepte maintenant un 4ème paramètre `user_agent`
- ✅ `project_create_interactive()` - Demande le User-Agent lors de la création
- ✅ `project_set_user_agent()` - Nouvelle commande pour modifier le User-Agent
- ✅ `project_get_user_agent()` - Nouvelle commande pour consulter le User-Agent
- ✅ Métadonnées du projet incluent maintenant le User-Agent

#### 3. HTTP Helper
**Fichier** : `core/http_helper.sh` (NOUVEAU)
- ✅ `get_project_user_agent(project_id)` - Helper pour récupérer le User-Agent
- ✅ `project_curl(...)` - curl wrapper utilisant le User-Agent du projet
- ✅ `vuln_curl(project_id, ...)` - curl optimisé pour les tests de vulnérabilités

#### 4. Modules de tests
**Fichier** : `modules/vulnerability_tests/xss_module.sh`
- ✅ Ajout du source `http_helper.sh`
- ✅ Utilisation de `vuln_curl` pour les requêtes HTTP

**Note** : Les autres modules (SQLi, CSRF, SSRF, CORS, etc.) peuvent être mis à jour de la même manière pour utiliser `vuln_curl`.

#### 5. Migration
**Fichier** : `scripts/migrate_user_agent.sh` (NOUVEAU)
- ✅ Script de migration pour les bases de données existantes
- ✅ Ajout automatique de la colonne `user_agent` si absente

### 📚 Documentation
- ✅ `USER_AGENT_FEATURE.md` - Documentation complète de la fonctionnalité
- ✅ `CHANGELOG_USER_AGENT.md` - Ce fichier

### 🚀 Utilisation

#### Création de projet avec User-Agent
```bash
./leknight.sh
> project create "Bug Bounty XYZ" "HackerOne" "example.com" "Mozilla/5.0 -BugBounty-memento-31337"
```

#### Modification du User-Agent
```bash
> project load 1
> project set-user-agent "Mozilla/5.0 -BugBounty-memento-31337"
```

#### Consultation du User-Agent
```bash
> project get-user-agent
```

### 🔄 Migration pour bases existantes

Si vous avez déjà une base de données LeKnight :

```bash
bash scripts/migrate_user_agent.sh
```

### ⚙️ User-Agent par défaut

Si aucun User-Agent n'est configuré :
```
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36
```

### 🎯 Cas d'usage Bug Bounty

#### HackerOne
```bash
> project set-user-agent "Mozilla/5.0 -HackerOne-username"
```

#### YesWeHack
```bash
> project set-user-agent "Mozilla/5.0 -YWH-hunter123"
```

#### Bugcrowd
```bash
> project set-user-agent "Mozilla/5.0 -Bugcrowd-researcher"
```

#### Custom
```bash
> project set-user-agent "Mozilla/5.0 -BugBounty-memento-31337"
```

### ✅ Compatibilité

- ✅ Rétrocompatible avec les projets existants
- ✅ User-Agent optionnel (utilise un défaut si non configuré)
- ✅ Compatible avec tous les workflows
- ✅ Compatible avec l'autopilot
- ✅ Compatible avec tous les modules de tests

### 🔍 Vérification

Pour vérifier que le User-Agent est utilisé :

1. **Logs de scan** : Consultez `data/logs/leknight.log`
2. **Proxy** : Interceptez avec Burp Suite ou OWASP ZAP
3. **Project info** : `> project info` affiche le User-Agent

### 📊 Impact

- **Base de données** : Ajout d'une colonne (migration automatique)
- **Performance** : Aucun impact
- **API** : Modifications rétrocompatibles
- **Stockage** : ~50 bytes par projet

### 🐛 Bugs connus

Aucun

### 📝 TODO (Améliorations futures)

- [ ] Mettre à jour tous les modules de tests pour utiliser `vuln_curl`
- [ ] Ajouter support User-Agent dans les wordlists de fuzzing
- [ ] Afficher le User-Agent dans le dashboard
- [ ] Permettre User-Agent différent par target (optionnel)
- [ ] Historique des User-Agent utilisés
- [ ] Templates de User-Agent pour plateformes courantes

### 🙏 Contribution

Cette fonctionnalité a été développée pour répondre aux besoins des programmes de bug bounty qui requièrent un User-Agent spécifique pour identifier les testeurs autorisés.

### 📞 Support

Pour toute question :
- Documentation : `USER_AGENT_FEATURE.md`
- Exemples : Voir ci-dessus
- Migration : `bash scripts/migrate_user_agent.sh`

---

**Version** : 2.1.0
**Date** : 2024-11-07
**Auteur** : LeKnight Development Team
**Status** : ✅ Stable
