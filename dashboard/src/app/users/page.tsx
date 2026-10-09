"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { useI18n } from "@/components/LanguageProvider";
import ForbiddenError from "@/components/ForbiddenError";

type User = {
  id: string;
  phone: string;
  full_name?: string | null;
  role: string;
  preferred_lang: string;
  is_active: boolean;
  created_at: string;
};

const ROLES = [
  { key: "all", labelFr: "Tous les rôles", labelAr: "جميع الأدوار" },
  { key: "agent", labelFr: "Chauffeurs (Agents)", labelAr: "السائقون (الموزعون)" },
  { key: "dispatcher", labelFr: "Régulateurs (Dispatch)", labelAr: "مسؤولو التوزيع" },
  { key: "warehouse", labelFr: "Magasiniers (Dépôt)", labelAr: "مسؤولو المستودع" },
  { key: "accountant", labelFr: "Comptables (Caisse)", labelAr: "المحاسبون" },
  { key: "owner", labelFr: "Gérants (Propriétaires)", labelAr: "المدراء" },
  { key: "auditor", labelFr: "Auditeurs (CNDP / ADR)", labelAr: "المراقبون" },
];

const ROLE_PERMS: Record<string, { descFr: string; descAr: string; perms: string[] }> = {
  owner: {
    descFr: "Administration totale du tenant, gestion financière et tarification.",
    descAr: "إدارة كاملة للفرع، التحكم المالي والتسعير.",
    perms: ["Toutes permissions", "Gestion des utilisateurs", "Création des dépôts & camions", "Consultation de l'audit"],
  },
  dispatcher: {
    descFr: "Planification des tournées, optimisation 2-opt et assignation des camions.",
    descAr: "تخطيط المسارات وتحسين المحطات وإسناد الشاحنات.",
    perms: ["Création & publication des tournées", "Suivi temps réel des camions", "Plafonds crédit & dérogations"],
  },
  warehouse: {
    descFr: "Supervision des mouvements de stock et validation chargement/déchargement.",
    descAr: "مراقبة حركة المخزون وتأكيد الشحن والتفريغ.",
    perms: ["Validation chargement camion", "Comptage retours vides/défectueux", "Inventaire dépôt central"],
  },
  agent: {
    descFr: "Opérations terrain mobile, livraison géofencée, encaissement et signature CNDP.",
    descAr: "العمليات الميدانية على التطبيق، التسليم الموثق، التحصيل النقد والتوقيع.",
    perms: ["Authentification Empreinte / Face ID", "Check-in GPS géofencé", "Encaissement espèces", "Signature client hors-ligne"],
  },
  accountant: {
    descFr: "Contrôle des versements, validation des clôtures de shift et gestion des impayés.",
    descAr: "مراقبة المداخيل وتأكيد إغلاق الجولات والتحكم في الديون.",
    perms: ["Clôture financière des tournées", "Traitement des écarts de caisse", "Relevés de comptes détaillants"],
  },
  auditor: {
    descFr: "Accès en lecture seule aux journaux de traçabilité immuables et rapports sécurité.",
    descAr: "اطلاع غير قابل للتعديل على سجلات التدقيق وتقارير السلامة.",
    perms: ["Journal d'audit cryptographique", "Historique incidents ADR", "Traçabilité des dérogations"],
  },
};

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [roleFilter, setRoleFilter] = useState("all");
  const [search, setSearch] = useState("");
  const [showCreate, setShowCreate] = useState(false);
  const [editingUserId, setEditingUserId] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const { t, locale } = useI18n();
  const isAr = locale === "ar";

  // Form State
  const [phone, setPhone] = useState("+212");
  const [fullName, setFullName] = useState("");
  const [role, setRole] = useState("agent");
  const [preferredLang, setPreferredLang] = useState("fr");
  const [password, setPassword] = useState("");

  async function loadUsers() {
    try {
      const data = await api<User[]>("/api/v1/users");
      setUsers(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  useEffect(() => {
    (async () => {
      await loadUsers();
    })();
  }, []);

  async function handleCreateUser(e: React.FormEvent) {
    e.preventDefault();
    setIsSubmitting(true);
    setError("");
    setSuccess("");
    try {
      if (editingUserId) {
        await api(`/api/v1/users/${editingUserId}`, {
          method: "PATCH",
          body: JSON.stringify({
            phone: phone.trim() || undefined,
            full_name: fullName.trim() || undefined,
            role,
            preferred_lang: preferredLang,
            password: password.trim() || undefined,
          }),
        });
        setSuccess(
          isAr
            ? `تم تحديث المستخدم بنجاح.`
            : `Utilisateur mis à jour avec succès.`
        );
      } else {
        await api("/api/v1/users", {
          method: "POST",
          body: JSON.stringify({
            phone: phone.trim(),
            full_name: fullName.trim() || undefined,
            role,
            preferred_lang: preferredLang,
            password: password.trim() || undefined,
          }),
        });
        setSuccess(
          isAr
            ? `تم إنشاء المستخدم (${phone}) بنجاح.`
            : `Utilisateur (${phone}) créé avec succès avec le rôle [${role}].`
        );
      }

      setShowCreate(false);
      setEditingUserId(null);
      setPhone("+212");
      setFullName("");
      setPassword("");
      await loadUsers();
      setTimeout(() => setSuccess(""), 5000);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleToggleStatus(user: User) {
    try {
      await api(`/api/v1/users/${user.id}`, {
        method: user.is_active ? "DELETE" : "PATCH",
        body: user.is_active ? undefined : JSON.stringify({ is_active: true }),
      });
      setSuccess(isAr ? "تم تغيير حالة المستخدم بنجاح." : "Statut mis à jour avec succès.");
      await loadUsers();
      setTimeout(() => setSuccess(""), 3000);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  function openEditModal(user: User) {
    setPhone(user.phone);
    setFullName(user.full_name || "");
    setRole(user.role);
    setPreferredLang(user.preferred_lang);
    setPassword("");
    setEditingUserId(user.id);
    setShowCreate(true);
  }

  function openCreateModal() {
    setPhone("+212");
    setFullName("");
    setRole("agent");
    setPreferredLang("fr");
    setPassword("");
    setEditingUserId(null);
    setShowCreate(true);
  }

  const filteredUsers = users.filter((u) => {
    const matchesRole = roleFilter === "all" || u.role === roleFilter;
    const matchesSearch =
      !search ||
      u.phone.toLowerCase().includes(search.toLowerCase()) ||
      (u.full_name && u.full_name.toLowerCase().includes(search.toLowerCase())) ||
      u.role.toLowerCase().includes(search.toLowerCase());
    return matchesRole && matchesSearch;
  });

  function getRoleBadgeColor(roleName: string) {
    switch (roleName) {
      case "owner":
        return "badge-purple";
      case "dispatcher":
        return "badge-blue";
      case "warehouse":
        return "badge-amber";
      case "agent":
        return "badge-green";
      case "accountant":
        return "badge-cyan";
      default:
        return "badge-neutral";
    }
  }

  if (error && error.toLowerCase().includes("not permitted")) {
    return <ForbiddenError error={error} />;
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
      {/* Editorial Header */}
      <header className="page-header" style={{ marginBottom: 0 }}>
        <div>
          <div className="section-label" style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <span style={{ width: "8px", height: "8px", background: "var(--accent-amber)", display: "inline-block" }}></span>
            <span>{isAr ? "إدارة الفريق والأمان البيومتري" : "ÉQUIPE, RÔLES & AUTHENTIFICATION BIOMÉTRIQUE"}</span>
          </div>
          <h1 className="page-title">{isAr ? "المستخدمون والصلاحيات" : "Utilisateurs & Contrôle d'Accès"}</h1>
          <p className="page-sub">
            {isAr
              ? "إدارة حسابات السائقين والمنظمين والمحاسبين مع التحقق بالبصمة والوجه (Face ID / Fingerprint)"
              : "Provisionnement des comptes, gestion des permissions RBAC et statut de l'authentification biométrique mobile"}
          </p>
        </div>

        <div style={{ display: "flex", gap: "12px", alignItems: "center" }}>
          <button
            type="button"
            className="btn primary"
            onClick={openCreateModal}
            style={{ display: "flex", alignItems: "center", gap: "8px" }}
          >
            <span>+</span>
            <span>{isAr ? "إضافة مستخدم جديد" : "Ajouter un Utilisateur"}</span>
          </button>
        </div>
      </header>

      {/* Biometric & Security Hardware Diagnostics Banner */}
      <div
        className="card-editorial"
        style={{
          borderLeft: "4px solid var(--accent-amber)",
          background: "linear-gradient(90deg, rgba(245,158,11,0.08) 0%, rgba(14,20,30,0.6) 100%)",
        }}
      >
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: "16px" }}>
          <div style={{ display: "flex", gap: "16px", alignItems: "center" }}>
            <div
              style={{
                width: "48px",
                height: "48px",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                background: "var(--bg-surface-2)",
                border: "1px solid var(--accent-amber)",
                fontSize: "22px",
              }}
            >
              🔐
            </div>
            <div>
              <div style={{ fontFamily: "var(--font-headline)", fontWeight: 700, fontSize: "16px", color: "var(--ink-primary)" }}>
                {isAr ? "بروتوكول المصادقة البيومترية المشفرة (Face & Fingerprint)" : "Protocole Biométrique Matériel (Empreinte & Face ID)"}
              </div>
              <div style={{ fontSize: "13px", color: "var(--ink-secondary)", marginTop: "2px" }}>
                {isAr
                  ? "تطبيق السائقين الميدانيين يدعم المصادقة المباشرة عبر مستشعر البصمة وميزة التعرف على الوجه مع تخزين المفاتيح في Keystore المحلي."
                  : "Les chauffeurs sur le terrain utilisent BiometricPrompt (Android Keystore) sans transmission d'images brutes, conforme CNDP n°09-08."}
              </div>
            </div>
          </div>

          <div style={{ display: "flex", gap: "12px" }}>
            <div style={{ padding: "8px 14px", background: "var(--bg-surface-3)", border: "1px solid var(--border-raw)" }}>
              <div className="label-editorial" style={{ fontSize: "10px", color: "var(--ink-muted)" }}>AGENT BIOMETRIC READY</div>
              <div style={{ fontFamily: "var(--font-mono)", fontSize: "14px", fontWeight: 700, color: "var(--signal-ok)" }}>● ACTIF (v2.3)</div>
            </div>
            <div style={{ padding: "8px 14px", background: "var(--bg-surface-3)", border: "1px solid var(--border-raw)" }}>
              <div className="label-editorial" style={{ fontSize: "10px", color: "var(--ink-muted)" }}>SMS OTP GATEWAY</div>
              <div style={{ fontFamily: "var(--font-mono)", fontSize: "14px", fontWeight: 700, color: "var(--accent-amber)" }}>● +212 (DEV STUB)</div>
            </div>
          </div>
        </div>
      </div>

      {error && (
        <div style={{ padding: "12px 16px", background: "var(--signal-danger-bg)", border: "1px solid var(--signal-danger-border)", color: "#FCA5A5" }}>
          ⚠️ {error}
        </div>
      )}

      {success && (
        <div style={{ padding: "12px 16px", background: "var(--signal-ok-bg)", border: "1px solid var(--signal-ok-border)", color: "#86EFAC" }}>
          ✓ {success}
        </div>
      )}

      {/* Main Content Layout: Grid */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 340px", gap: "24px", alignItems: "start" }}>
        {/* Left Column: Users Directory */}
        <div>
          {/* Controls Bar */}
          <div className="card-editorial" style={{ padding: "16px", marginBottom: "16px" }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: "12px", flexWrap: "wrap" }}>
              {/* Role filter buttons */}
              <div style={{ display: "flex", gap: "6px", flexWrap: "wrap" }}>
                {ROLES.map((r) => (
                  <button
                    key={r.key}
                    type="button"
                    onClick={() => setRoleFilter(r.key)}
                    className={`btn sm ${roleFilter === r.key ? "primary" : "secondary"}`}
                    style={{ fontSize: "11px", padding: "6px 10px" }}
                  >
                    {isAr ? r.labelAr : r.labelFr}
                  </button>
                ))}
              </div>

              {/* Search */}
              <div style={{ minWidth: "220px" }}>
                <input
                  type="text"
                  placeholder={isAr ? "بحث بالهاتف أو الاسم..." : "Rechercher un membre..."}
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  style={{ width: "100%", padding: "8px 12px", fontSize: "12px" }}
                />
              </div>
            </div>
          </div>

          {/* Users Table */}
          <div className="card-editorial" style={{ padding: 0, overflow: "hidden" }}>
            <div className="panel-header" style={{ padding: "16px 20px" }}>
              <div className="panel-title">{isAr ? "أعضاء الفريق المسجلون" : "Membres de l'Équipe & Rôles"}</div>
              <div style={{ fontFamily: "var(--font-mono)", fontSize: "12px", color: "var(--ink-secondary)" }}>
                {filteredUsers.length} / {users.length} {isAr ? "مستخدم" : "comptes"}
              </div>
            </div>

            <div style={{ overflowX: "auto" }}>
              <table className="table-editorial" style={{ width: "100%" }}>
                <thead>
                  <tr>
                    <th>{isAr ? "الاسم / الهاتف" : "UTILISATEUR / TÉLÉPHONE"}</th>
                    <th>{isAr ? "الدور الوظيفي" : "RÔLE RBAC"}</th>
                    <th>{isAr ? "اللغة" : "LANGUE"}</th>
                    <th>{isAr ? "المصادقة" : "MÉTHODES D'ACCÈS"}</th>
                    <th>{isAr ? "الحالة" : "STATUT"}</th>
                    <th style={{ textAlign: "right" }}>{isAr ? "إجراءات" : "ACTIONS"}</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredUsers.map((u) => (
                    <tr key={u.id}>
                      <td>
                        <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                          <div
                            style={{
                              width: "32px",
                              height: "32px",
                              background: "var(--bg-surface-3)",
                              border: "1px solid var(--border-raw)",
                              display: "flex",
                              alignItems: "center",
                              justifyContent: "center",
                              fontSize: "14px",
                            }}
                          >
                            {u.role === "agent" ? "🚚" : u.role === "owner" ? "👑" : u.role === "accountant" ? "💼" : "👤"}
                          </div>
                          <div>
                            <div style={{ fontWeight: 600, color: "var(--ink-primary)" }}>
                              {u.full_name || (u.role === "agent" ? `Chauffeur (${u.phone})` : u.phone)}
                            </div>
                            <div style={{ fontFamily: "var(--font-mono)", fontSize: "11px", color: "var(--ink-muted)" }}>
                              {u.phone}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <span className={`badge ${getRoleBadgeColor(u.role)}`}>
                          {u.role.toUpperCase()}
                        </span>
                      </td>
                      <td>
                        <span style={{ fontFamily: "var(--font-mono)", fontSize: "11px", color: "var(--ink-secondary)" }}>
                          {u.preferred_lang.toUpperCase()}
                        </span>
                      </td>
                      <td>
                        <div style={{ display: "flex", gap: "6px", alignItems: "center" }}>
                          <span title="SMS OTP" style={{ fontSize: "12px", opacity: 0.9 }}>📱 OTP</span>
                          {u.role === "agent" && (
                            <span
                              title="Support Empreinte Digitale et Face ID"
                              style={{
                                padding: "2px 6px",
                                background: "rgba(16,185,129,0.15)",
                                border: "1px solid var(--signal-ok-border)",
                                color: "var(--signal-ok)",
                                fontSize: "10px",
                                fontWeight: 700,
                              }}
                            >
                              👆 BIOMÉTRIE
                            </span>
                          )}
                        </div>
                      </td>
                      <td>
                        <span style={{ display: "inline-flex", alignItems: "center", gap: "6px", fontSize: "12px" }}>
                          <span style={{ width: "6px", height: "6px", borderRadius: "50%", background: u.is_active ? "var(--signal-ok)" : "var(--signal-danger)" }}></span>
                          <span style={{ color: u.is_active ? "var(--signal-ok)" : "var(--signal-danger)", fontWeight: 600 }}>
                            {u.is_active ? (isAr ? "نشط" : "Actif") : (isAr ? "معطل" : "Inactif")}
                          </span>
                        </span>
                      </td>
                      <td style={{ textAlign: "right", whiteSpace: "nowrap" }}>
                        <button
                          type="button"
                          className="btn secondary sm"
                          onClick={() => openEditModal(u)}
                          style={{ marginRight: "8px", padding: "4px 8px" }}
                          title={isAr ? "تعديل" : "Modifier"}
                        >
                          ✎
                        </button>
                        <button
                          type="button"
                          className={`btn ${u.is_active ? 'danger' : 'primary'} sm`}
                          onClick={() => handleToggleStatus(u)}
                          style={{ padding: "4px 8px" }}
                          title={isAr ? (u.is_active ? "تعطيل" : "تفعيل") : (u.is_active ? "Désactiver" : "Activer")}
                        >
                          {u.is_active ? "✕" : "✓"}
                        </button>
                      </td>
                    </tr>
                  ))}

                  {filteredUsers.length === 0 && (
                    <tr>
                      <td colSpan={6} style={{ textAlign: "center", padding: "32px", color: "var(--ink-muted)" }}>
                        {isAr ? "لا يوجد مستخدمون يطابقون خيارات البحث." : "Aucun utilisateur ne correspond aux critères."}
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        {/* Right Column: Roles & Permissions Matrix */}
        <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
          <div className="card-editorial" style={{ padding: "20px" }}>
            <div className="panel-title" style={{ marginBottom: "12px" }}>
              {isAr ? "مصفوفة الصلاحيات (RBAC)" : "Matrice des Droits & Rôles"}
            </div>
            <p style={{ fontSize: "12px", color: "var(--ink-secondary)", marginBottom: "16px" }}>
              {isAr
                ? "يتم فرض الصلاحيات بدقة في الخلفية البرمجية عبر التحقق من الرموز (JWT Dep Guards)."
                : "Chaque rôle dispose d'un périmètre d'action strict vérifié au niveau API (FastAPI Guards)."}
            </p>

            <div style={{ display: "flex", flexDirection: "column", gap: "14px" }}>
              {Object.entries(ROLE_PERMS).map(([rKey, info]) => (
                <div
                  key={rKey}
                  style={{
                    padding: "12px",
                    background: "var(--bg-surface-2)",
                    border: "1px solid var(--border-raw)",
                    borderLeft: `3px solid ${
                      rKey === "owner"
                        ? "#A855F7"
                        : rKey === "dispatcher"
                        ? "#38BDF8"
                        : rKey === "warehouse"
                        ? "var(--accent-amber)"
                        : rKey === "agent"
                        ? "var(--signal-ok)"
                        : "#94A3B8"
                    }`,
                  }}
                >
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "4px" }}>
                    <span style={{ fontWeight: 700, fontSize: "13px", color: "var(--ink-primary)" }}>
                      {rKey.toUpperCase()}
                    </span>
                    <span style={{ fontSize: "10px", color: "var(--ink-muted)" }}>{info.perms.length} droits</span>
                  </div>
                  <div style={{ fontSize: "11px", color: "var(--ink-muted)", marginBottom: "8px" }}>
                    {isAr ? info.descAr : info.descFr}
                  </div>
                  <div style={{ display: "flex", flexDirection: "column", gap: "3px" }}>
                    {info.perms.map((p, idx) => (
                      <div key={idx} style={{ fontSize: "11px", color: "var(--ink-secondary)", display: "flex", alignItems: "center", gap: "6px" }}>
                        <span style={{ color: "var(--accent-amber)" }}>•</span>
                        <span>{p}</span>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Create User Modal */}
      {showCreate && (
        <div className="modal-backdrop" onClick={() => { setShowCreate(false); setEditingUserId(null); }}>
          <div className="modal-card" onClick={(e) => e.stopPropagation()} style={{ maxWidth: "520px" }}>
            <div className="modal-header">
              <div className="panel-title">{editingUserId ? (isAr ? "تعديل المستخدم" : "Modifier l'Utilisateur") : (isAr ? "إضافة مستخدم جديد" : "Création d'un Nouveau Compte")}</div>
              <button
                type="button"
                className="btn secondary sm"
                onClick={() => { setShowCreate(false); setEditingUserId(null); }}
                aria-label="Fermer"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleCreateUser}>
              <div className="modal-body" style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
                <div>
                  <label className="form-label">{isAr ? "رقم الهاتف (التعريف)" : "Numéro de Téléphone (Identifiant OTP)"}</label>
                  <input
                    type="text"
                    required
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="+212600000000"
                    style={{ width: "100%", fontFamily: "var(--font-mono)" }}
                  />
                  <span style={{ fontSize: "11px", color: "var(--ink-muted)", marginTop: "4px", display: "block" }}>
                    {isAr ? "يستخدم لتسجيل الدخول وإرسال رمز التحقق OTP." : "Utilisé pour la réception du code SMS et le déverrouillage biométrique."}
                  </span>
                </div>

                <div>
                  <label className="form-label">{isAr ? "الاسم الكامل (اختياري)" : "Nom Complet de l'Agent / Collaborateur"}</label>
                  <input
                    type="text"
                    value={fullName}
                    onChange={(e) => setFullName(e.target.value)}
                    placeholder="Ex: Youssef Benjelloun"
                    style={{ width: "100%" }}
                  />
                </div>

                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "12px" }}>
                  <div>
                    <label className="form-label">{isAr ? "الدور الوظيفي (RBAC)" : "Rôle Attribué"}</label>
                    <select
                      value={role}
                      onChange={(e) => setRole(e.target.value)}
                      style={{ width: "100%" }}
                    >
                      <option value="agent">Agent / Chauffeur Livreur</option>
                      <option value="dispatcher">Dispatcher / Régulateur</option>
                      <option value="warehouse">Magasinier / Dépôt</option>
                      <option value="accountant">Comptable / Trésorerie</option>
                      <option value="auditor">Auditeur / Conformité</option>
                      <option value="owner">Gérant / Propriétaire</option>
                    </select>
                  </div>

                  <div>
                    <label className="form-label">{isAr ? "اللغة المفضلة" : "Langue Préférée"}</label>
                    <select
                      value={preferredLang}
                      onChange={(e) => setPreferredLang(e.target.value)}
                      style={{ width: "100%" }}
                    >
                      <option value="fr">Français</option>
                      <option value="ar">العربية</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label className="form-label">{isAr ? "كلمة المرور (اختياري للإدارة)" : "Mot de passe d'administration (Optionnel)"}</label>
                  <input
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="••••••••"
                    style={{ width: "100%" }}
                  />
                </div>
              </div>

              {error && (
                <div style={{ padding: "12px 16px", margin: "16px 20px 0 20px", background: "var(--signal-danger-bg)", border: "1px solid var(--signal-danger-border)", color: "#FCA5A5" }}>
                  ⚠️ {error}
                </div>
              )}

              <div className="modal-footer">
                <button
                  type="button"
                  className="btn secondary"
                  onClick={() => { setShowCreate(false); setEditingUserId(null); }}
                >
                  {isAr ? "إلغاء" : "Annuler"}
                </button>
                <button
                  type="submit"
                  className="btn primary"
                  disabled={isSubmitting}
                >
                  {isSubmitting ? (isAr ? "جاري الحفظ..." : "Sauvegarde…") : (isAr ? "حفظ المستخدم" : "Enregistrer l'Utilisateur")}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
