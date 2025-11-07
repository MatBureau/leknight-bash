# LeKnight - Advanced Security Testing Features

## 🎯 Vue d'ensemble

J'ai implémenté un **pipeline de sécurité avancé en 5 phases** qui transforme LeKnight en un framework d'exploitation complet. L'autopilot exécute maintenant automatiquement :

- ✅ Fuzzing avancé (FFUF)
- ✅ DNS dump complet avec DNSSEC, SPF, DMARC
- ✅ Tests de 10 types de vulnérabilités OWASP
- ✅ Formatage des résultats pour exploitation
- ✅ Génération de PoC et scripts d'exploitation

---

## 🚀 Les 5 Phases de l'Autopilot

### **Phase 1 : Reconnaissance**
- DNS dump avancé (zone transfer, DNSSEC, SPF/DMARC/DKIM)
- Énumération de subdomains (Subfinder, Amass)
- Fingerprinting technologique (WhatWeb)
- Découverte de vhosts

### **Phase 2 : Énumération**
- Scan de ports (Nmap avec détection de services)
- **Fuzzing complet avec FFUF** :
  - Directories/Files
  - Paramètres GET/POST
  - Virtual hosts
  - Headers HTTP
  - Extensions de fichiers
  - Endpoints API
- Analyse SSL/TLS (SSLyze)

### **Phase 3 : Scan de vulnérabilités**
- Templates Nuclei (critical, high, medium)
- Nikto web scanner
- WPScan (si WordPress détecté)
- Détection automatique de technologies

### **Phase 4 : Tests d'exploitation** ⚡ **NOUVEAU**

Tests automatisés pour :

#### **Injection Flaws**
- **XSS** (Reflected, Stored, DOM-based)
- **SQLi** (Error-based, Boolean-blind, Time-based) + SQLMap
- **XXE** (XML External Entity)
- **RCE** (Command injection, Code injection, SSTI)
- **LFI/RFI** (Path traversal, File disclosure)

#### **Broken Authentication**
- **CSRF** (Token validation, SameSite cookies, Referer checks)
- **IDOR** (Numeric IDs, GUIDs, Filename manipulation)

#### **Server-Side Vulnerabilities**
- **SSRF** (Internal network, Cloud metadata, Protocol smuggling)
- **XSPA** (Port scanning via SSRF, Service detection)

#### **Security Misconfiguration**
- **CORS** (Wildcard, Origin reflection, Null origin)

### **Phase 5 : Post-Exploitation & Reporting**
- Formatage des résultats pour exploitation
- Génération de scripts SQLMap
- Création de PoC HTML/JavaScript
- Guides d'exploitation
- Rapports Markdown complets

---

## 📁 Architecture des modules

```
modules/vulnerability_tests/
├── xss_module.sh          # Tests XSS (reflected, stored, DOM)
├── sqli_module.sh         # Tests SQL injection + SQLMap
├── csrf_module.sh         # Tests CSRF avec PoC
├── idor_module.sh         # Tests IDOR (IDs, GUIDs, files)
├── rce_module.sh          # Tests RCE/Command injection
├── lfi_rfi_module.sh      # Tests LFI/RFI/Path traversal
├── xxe_module.sh          # Tests XXE
├── ssrf_module.sh         # Tests SSRF + Cloud metadata
├── xspa_module.sh         # Tests XSPA/Port scanning
└── cors_module.sh         # Tests CORS misconfigurations

workflows/
├── autopilot_advanced.sh  # Pipeline 5 phases
├── fuzzing_pipeline.sh    # Fuzzing FFUF complet
├── dns_dump_advanced.sh   # DNS recon avancé
└── vulnerability_testing.sh  # Orchestrateur de tests

core/
└── result_formatter.sh    # Formatage pour exploitation
```

---

## 🔧 Utilisation

### **Mode Standard (activé par défaut)**

L'autopilot utilise automatiquement le pipeline avancé :

```bash
./leknight.sh
project create "Mon projet"
project scope add "example.com"
autopilot start
```

### **Désactiver le mode avancé**

```bash
export LEKNIGHT_ADVANCED_MODE=false
./leknight.sh
```

### **Fuzzing manuel**

```bash
# Dans le shell LeKnight
source workflows/fuzzing_pipeline.sh
fuzzing_pipeline "https://example.com" <project_id> "deep"
```

### **Tests de vulnérabilités manuels**

```bash
source workflows/vulnerability_testing.sh

# Tous les tests
vulnerability_testing_pipeline "https://example.com" <project_id> "all"

# Seulement injection
vulnerability_testing_pipeline "https://example.com" <project_id> "injection"

# Seulement auth
vulnerability_testing_pipeline "https://example.com" <project_id> "auth"
```

---

## 📊 Résultats et Exploitation

### **Structure des données**

```
data/projects/<project_id>/
├── scans/
│   ├── fuzzing/              # Résultats FFUF (JSON)
│   ├── dns/                  # DNS dump complet
│   └── vulnerability_test_report.txt
├── evidence/                 # Preuves de vulnérabilités
│   ├── xss/                  # Captures XSS
│   ├── sqli/                 # Preuves SQLi
│   ├── csrf/                 # PoC CSRF
│   ├── ssrf/                 # Tests SSRF
│   └── cors/                 # Misconfigurations CORS
└── exploits/                 # Scripts d'exploitation
    ├── sqli_*.sh             # Scripts SQLMap
    ├── xss_*.html            # PoC XSS
    ├── rce_*.sh              # Scripts RCE
    ├── csrf_*.html           # PoC CSRF
    └── INDEX.md              # Index des exploits
```

### **Exemple de sortie d'exploitation**

```bash
data/projects/1/exploits/
├── sqli_5.sh               # Script SQLMap prêt à l'emploi
├── sqli_5.json             # Metadata
├── xss_12.html             # PoC XSS avec cookie stealing
├── rce_8.sh                # Reverse shell commands
├── csrf_3.html             # Auto-submitting CSRF form
└── INDEX.md                # Liste tous les exploits
```

---

## 🎨 Fonctionnalités avancées

### **1. Fuzzing intelligent**

- Détection automatique d'API (JSON, REST, GraphQL)
- Recursion de directories
- Filtrage par codes HTTP
- Prioritisation des endpoints sensibles (admin, api, config)
- Ajout automatique à la DB pour tests ultérieurs

### **2. DNS Security Assessment**

- Test de zone transfer (AXFR)
- Validation DNSSEC
- Analyse SPF/DMARC/DKIM
- Score de sécurité email (0-100)
- Détection de subdomain takeover potential
- CAA records check

### **3. Tests de vulnérabilités contextual**

Chaque module adapte ses tests selon :
- Type de paramètre détecté
- Technologie identifiée
- Réponses du serveur
- Timing-based detection

### **4. Génération automatique de PoC**

- **CSRF** : Forms HTML auto-submit
- **XSS** : Cookie stealing, keylogging
- **SQLi** : Commands SQLMap
- **RCE** : Reverse shell payloads
- **SSRF** : Cloud metadata queries

### **5. Corrélation de résultats**

Les résultats de fuzzing alimentent automatiquement les tests de vulnérabilités :

```
Fuzzing trouve : /admin/upload.php
    ↓
Auto-ajouté à targets table
    ↓
Phase 4 teste : XSS, SQLi, LFI, Upload bypass
    ↓
Findings ajoutés à DB
    ↓
Phase 5 génère exploits
```

---

## ⚙️ Configuration

### **Variables d'environnement**

```bash
# Mode avancé (défaut: true)
export LEKNIGHT_ADVANCED_MODE=true

# Auto-exploitation (défaut: false)
export AUTOPILOT_AUTO_EXPLOIT=false

# Profondeur fuzzing (quick, medium, deep)
export LEKNIGHT_FUZZ_DEPTH=medium

# Rate limiting (requests/sec)
export MAX_REQUESTS_PER_SECOND=100
```

### **Wordlists**

Le système crée automatiquement des wordlists par défaut dans `data/wordlists/`, mais vous pouvez utiliser SecLists :

```bash
# Installer SecLists
git clone https://github.com/danielmiessler/SecLists.git /usr/share/seclists

# Les modules détectent automatiquement SecLists
```

---

## 🔍 Détails techniques

### **Tests XSS**

```bash
# Reflected
- 18 payloads (basic, polyglot, filter bypass)
- Détection de contexte (HTML, JS, attr, URL)
- URL encoding automatique

# Stored
- Unique ID tracking
- Form auto-discovery
- Persistent payload verification

# DOM-based
- Detection de dangerous sinks
- Fragment-based payloads
- JavaScript analysis
```

### **Tests SQLi**

```bash
# Error-based
- 20+ payloads (MySQL, PostgreSQL, MSSQL, Oracle)
- Pattern matching pour erreurs
- Database fingerprinting

# Boolean-blind
- True/false condition testing
- Response length comparison
- Content differential analysis

# Time-based
- SLEEP/WAITFOR/pg_sleep/DBMS_LOCK
- Baseline timing measurement
- 5-second delay detection

# SQLMap integration
- Auto-launch sur vulnérabilité confirmée
- Full database dump
- Credential extraction
```

### **Tests SSRF**

```bash
# Internal network
- Localhost variants (127.0.0.1, ::1, 0.0.0.0)
- Private IP ranges (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
- Filter bypass (decimal, hex, DNS rebinding)

# Cloud metadata
- AWS (169.254.169.254)
- Google Cloud (metadata.google.internal)
- Azure (169.254.169.254 + headers)
- Digital Ocean, Oracle Cloud

# Protocol smuggling
- file://, gopher://, dict://, ftp://
```

### **Tests CORS**

```bash
# Wildcard check
- Access-Control-Allow-Origin: *
- + Credentials validation

# Origin reflection
- Evil origins testing
- Credential exposure

# Null origin
- Sandboxed iframe exploitation

# Subdomain trust
- Pattern matching vulnerabilities
- Subdomain takeover risk
```

---

## 📈 Métriques et Reporting

Chaque phase génère des rapports détaillés :

```
Fuzzing Summary:
- Directories found: 47
- Parameters discovered: 23
- High-value endpoints: 12

DNS Security Report:
- Email Security Score: 67/100
- DNSSEC: Enabled
- Zone Transfer: Protected

Vulnerability Test Report:
- Critical: 3 (SQLi x2, RCE x1)
- High: 8 (XSS x5, SSRF x2, IDOR x1)
- Medium: 15
- Low: 22
```

---

## ⚠️ Avertissements

### **Légal**
- ✅ Utilisez UNIQUEMENT sur des systèmes autorisés
- ✅ Obtenez une autorisation écrite
- ✅ Respectez les lois locales

### **Technique**
- Les tests peuvent être **bruyants** (beaucoup de requêtes)
- Certains tests peuvent **impacter les performances**
- L'auto-exploitation est **désactivée par défaut**
- Time-based tests ajoutent des **délais significatifs**

### **Responsabilité**
Ce framework est conçu pour des **tests de sécurité autorisés** uniquement. L'utilisation malveillante est strictement interdite et illégale.

---

## 🎓 Exemples d'utilisation

### **Scan complet d'un domaine**

```bash
./leknight.sh
> project create "Pentest Client XYZ"
> project scope add "example.com"
> autopilot start

# L'autopilot va :
# 1. DNS dump (SPF, DMARC, subdomains)
# 2. Fuzzing complet (dirs, params, vhosts)
# 3. Scan vulnérabilités (Nuclei, Nikto)
# 4. Test OWASP Top 10 (XSS, SQLi, CSRF, etc.)
# 5. Générer exploits et rapports
```

### **Test ciblé sur une URL**

```bash
> project add-target "https://example.com/admin/login.php"
> autopilot start

# Tests spécifiques :
# - SQLi sur formulaire login
# - XSS sur tous paramètres
# - CSRF sur POST requests
# - Brute-force avec Hydra
```

### **Exploitation manuelle**

```bash
# Après les scans
> cd data/projects/1/exploits/
> cat INDEX.md                    # Voir les vulnérabilités
> ./sqli_5.sh                     # Lancer SQLMap
> firefox xss_12.html             # Tester PoC XSS
> bash rce_8.sh                   # Commands RCE
```

---

## 🔧 Dépendances optionnelles

Pour activer toutes les fonctionnalités :

```bash
# Fuzzing
apt install ffuf

# SQLMap
apt install sqlmap

# Subdomain enum
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# SSL/TLS testing
pip install sslyze

# Nuclei
go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
```

---

## 🎯 Roadmap

Fonctionnalités futures envisageables :
- [ ] Integration Metasploit complete
- [ ] Burp Suite API integration
- [ ] Automated privilege escalation
- [ ] Lateral movement automation
- [ ] C2 framework integration
- [ ] Web shell upload automation
- [ ] Password cracking pipeline
- [ ] Social engineering modules

---

## 📝 Changelog

### Version 2.0 (Actuelle)

✨ **Nouvelles fonctionnalités** :
- Pipeline 5 phases dans autopilot
- 10 modules de test de vulnérabilités
- Fuzzing avancé (FFUF)
- DNS dump complet
- Formatage pour exploitation
- Génération automatique de PoC
- Scripts SQLMap auto-générés
- Evidence collection automatique

🔧 **Améliorations** :
- Mode avancé activé par défaut
- Backward compatibility maintenue
- Performance optimisée (tests parallèles)
- Meilleure corrélation de données

---

**Développé pour LeKnight Bash** 🛡️

*Framework de sécurité offensif pour tests d'intrusion professionnels*
