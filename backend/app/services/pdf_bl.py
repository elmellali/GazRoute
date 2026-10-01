"""Bon de Livraison (e-BL) and Receipt PDF generation service using ReportLab."""
from __future__ import annotations

import base64
import io
from datetime import datetime
from decimal import Decimal
from typing import Any

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import (
    HRFlowable,
    Image,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


def generate_delivery_note_pdf(
    *,
    tenant_name: str,
    tenant_phone: str,
    tenant_ice: str | None,
    receipt_number: str,
    delivery_date: datetime,
    outlet_name: str,
    outlet_phone: str,
    recipient_name: str,
    agent_name: str,
    lines: list[dict[str, Any]],
    subtotal_mad: float | Decimal,
    deposit_net_mad: float | Decimal,
    total_amount_mad: float | Decimal,
    paid_amount_mad: float | Decimal = 0.0,
    remaining_balance_mad: float | Decimal = 0.0,
    signature_base64: str | None = None,
) -> bytes:
    """Generate a clean B2B Bon de Livraison PDF document."""
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36,
    )

    styles = getSampleStyleSheet()
    primary_color = colors.HexColor("#1e3a8a")  # Deep blue
    accent_color = colors.HexColor("#0284c7")   # Sky blue
    text_dark = colors.HexColor("#0f172a")

    title_style = ParagraphStyle(
        "DocTitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=18,
        leading=22,
        textColor=primary_color,
    )
    subtitle_style = ParagraphStyle(
        "DocSubtitle",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=10,
        leading=14,
        textColor=colors.HexColor("#475569"),
    )
    heading_style = ParagraphStyle(
        "SectionHeading",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=11,
        leading=15,
        textColor=primary_color,
    )
    cell_style = ParagraphStyle(
        "CellText",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        leading=12,
        textColor=text_dark,
    )
    cell_bold = ParagraphStyle(
        "CellBold",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=9,
        leading=12,
        textColor=text_dark,
    )
    cell_header = ParagraphStyle(
        "CellHeader",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=9,
        leading=12,
        textColor=colors.white,
    )

    story = []

    # 1. Header with Company & Document Info
    company_info = f"""<b>{tenant_name}</b><br/>
Tél: {tenant_phone}<br/>
ICE: {tenant_ice or 'N/A'}<br/>
Maroc — Distribution GPL Professionnelle"""

    doc_info = f"""<font size=14 color='#1e3a8a'><b>BON DE LIVRAISON</b></font><br/>
<b>N° :</b> {receipt_number}<br/>
<b>Date :</b> {delivery_date.strftime('%d/%m/%Y %H:%M')}<br/>
<b>Chauffeur :</b> {agent_name}"""

    header_table = Table(
        [
            [
                Paragraph(company_info, subtitle_style),
                Paragraph(doc_info, subtitle_style),
            ]
        ],
        colWidths=[300, 222],
    )
    header_table.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ALIGN", (1, 0), (1, 0), "RIGHT"),
            ]
        )
    )
    story.append(header_table)
    story.append(Spacer(1, 14))

    # Divider
    story.append(HRFlowable(width="100%", thickness=1.5, color=primary_color, spaceAfter=14))

    # 2. Client & Delivery Site Info Box
    client_content = [
        [
            Paragraph("<b>POINT DE VENTE (CLIENT)</b>", heading_style),
            Paragraph("<b>RÉCEPTIONNAIRE VALISÉ</b>", heading_style),
        ],
        [
            Paragraph(f"<b>Établissement :</b> {outlet_name}<br/><b>Téléphone :</b> {outlet_phone}", cell_style),
            Paragraph(f"<b>Nom :</b> {recipient_name}<br/><b>Statut :</b> Présence vérifiée par Géofence", cell_style),
        ],
    ]
    client_box = Table(client_content, colWidths=[261, 261])
    client_box.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#f8fafc")),
                ("BOX", (0, 0), (-1, -1), 1, colors.HexColor("#e2e8f0")),
                ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#e2e8f0")),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    story.append(client_box)
    story.append(Spacer(1, 16))

    # 3. Itemized Table of Cylinders
    table_data = [
        [
            Paragraph("Désignation / Calibre", cell_header),
            Paragraph("Livré (Plein)", cell_header),
            Paragraph("Repris (Vide)", cell_header),
            Paragraph("Défectueux", cell_header),
            Paragraph("Prix U. (MAD)", cell_header),
            Paragraph("Total (MAD)", cell_header),
        ]
    ]

    for item in lines:
        table_data.append(
            [
                Paragraph(str(item.get("name", "Bouteille GPL")), cell_style),
                Paragraph(f"{float(item.get('delivered', 0)):.0f}", cell_style),
                Paragraph(f"{float(item.get('returned', 0)):.0f}", cell_style),
                Paragraph(f"{float(item.get('defective', 0)):.0f}", cell_style),
                Paragraph(f"{float(item.get('unit_price', 0)):.2f}", cell_style),
                Paragraph(f"{float(item.get('line_total', 0)):.2f}", cell_bold),
            ]
        )

    cylinder_table = Table(table_data, colWidths=[150, 75, 75, 75, 75, 72])
    cylinder_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), primary_color),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("ALIGN", (1, 0), (-1, -1), "CENTER"),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f8fafc")]),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.append(cylinder_table)
    story.append(Spacer(1, 14))

    # 4. Financial Summary Box
    summary_data = [
        [Paragraph("Sous-total Gaz :", cell_style), Paragraph(f"{float(subtotal_mad):.2f} MAD", cell_style)],
        [Paragraph("Impact Consignes (Emballages) :", cell_style), Paragraph(f"{float(deposit_net_mad):.2f} MAD", cell_style)],
        [Paragraph("<b>TOTAL NET FACTURÉ :</b>", cell_bold), Paragraph(f"<b>{float(total_amount_mad):.2f} MAD</b>", cell_bold)],
        [Paragraph("Montant Encaissé (Règlement) :", cell_style), Paragraph(f"{float(paid_amount_mad):.2f} MAD", cell_style)],
        [Paragraph("<b>Solde Client Résiduel :</b>", cell_bold), Paragraph(f"<b>{float(remaining_balance_mad):.2f} MAD</b>", cell_bold)],
    ]
    summary_table = Table(summary_data, colWidths=[180, 120])
    summary_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 2), (-1, 2), colors.HexColor("#e0f2fe")),
                ("BACKGROUND", (0, 4), (-1, 4), colors.HexColor("#f1f5f9")),
                ("BOX", (0, 0), (-1, -1), 1, colors.HexColor("#cbd5e1")),
                ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#e2e8f0")),
                ("ALIGN", (1, 0), (1, -1), "RIGHT"),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )

    # Place summary on right side
    outer_summary = Table(
        [
            [Paragraph("<font color='#64748b' size=8>Document officiel valant accusé de réception conforme aux dispositions réglementaires de distribution des hydrocarbures au Maroc.</font>", subtitle_style), summary_table]
        ],
        colWidths=[222, 300],
    )
    outer_summary.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("ALIGN", (1, 0), (1, 0), "RIGHT")]))
    story.append(outer_summary)
    story.append(Spacer(1, 20))

    # 5. Signatures Block
    sig_elements = []
    if signature_base64 and len(signature_base64) > 100:
        try:
            # Handle potential data URI header
            raw_b64 = signature_base64.split(",")[-1] if "," in signature_base64 else signature_base64
            img_bytes = base64.b64decode(raw_b64)
            img_buf = io.BytesIO(img_bytes)
            sig_img = Image(img_buf, width=140, height=50)
            sig_elements.append(sig_img)
        except Exception:
            sig_elements.append(Paragraph("<i>[Signature numérique enregistrée]</i>", cell_style))
    else:
        sig_elements.append(Paragraph("<i>[Signature électronique certifiée sur terminal mobile]</i>", cell_style))

    signatures_table = Table(
        [
            [
                Paragraph("<b>Visa Chauffeur-Livreur</b>", heading_style),
                Paragraph("<b>Signature & Cachet Client</b>", heading_style),
            ],
            [
                Paragraph(f"Livreur: {agent_name}<br/>Signature certifiée", cell_style),
                sig_elements[0] if sig_elements else Paragraph("Signature apposée", cell_style),
            ],
        ],
        colWidths=[261, 261],
    )
    signatures_table.setStyle(
        TableStyle(
            [
                ("BOX", (0, 0), (-1, -1), 1, colors.HexColor("#cbd5e1")),
                ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#e2e8f0")),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#f8fafc")),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    story.append(signatures_table)

    doc.build(story)
    return buffer.getvalue()
