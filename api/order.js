const { Resend } = require('resend');

module.exports = async function handler(req, res) {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const { ime, prezime, adresa, grad, ptt, tel, napomena, artikli } = req.body;

  if (!ime || !prezime || !tel || !artikli || artikli.length === 0) {
    return res.status(400).json({ error: 'Nedostaju obavezni podaci.' });
  }

  const resend = new Resend(process.env.RESEND_API_KEY);
  const fmtKM  = n => n.toFixed(2).replace('.', ',') + ' KM';
  const dostava  = 10.00;
  const subtotal = artikli.reduce((s, a) => s + a.kolicina * 54.90, 0);
  const total    = subtotal + dostava;

  const artikliRows = artikli.map(a => `
    <tr>
      <td style="padding:10px 16px;border-bottom:1px solid #F0EBE4;font-size:15px;">Veličina <strong>${a.velicina}</strong></td>
      <td style="padding:10px 16px;border-bottom:1px solid #F0EBE4;font-size:15px;text-align:center;">${a.kolicina} par(a)</td>
      <td style="padding:10px 16px;border-bottom:1px solid #F0EBE4;font-size:15px;text-align:right;font-weight:600;">${fmtKM(a.kolicina * 54.90)}</td>
    </tr>`).join('');

  const html = `<!DOCTYPE html><html lang="bs"><head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#F5F3F0;font-family:'Segoe UI',Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#F5F3F0;padding:40px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.08);">
<tr><td style="background:linear-gradient(135deg,#FF5C2B,#FF8C42);padding:32px 40px;text-align:center;">
  <div style="font-size:28px;font-weight:900;letter-spacing:.04em;color:#fff;text-transform:uppercase;">ADEX <span style="opacity:.8;">PLUS</span></div>
  <div style="font-size:12px;color:rgba(255,255,255,.75);margin-top:4px;letter-spacing:.1em;text-transform:uppercase;">Nova narudžba primljena</div>
</td></tr>
<tr><td style="padding:32px 40px 0;">
  <div style="font-size:11px;font-weight:700;letter-spacing:.14em;text-transform:uppercase;color:#FF5C2B;margin-bottom:12px;">Podaci o kupcu</div>
  <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #EDEBE7;border-radius:10px;overflow:hidden;">
    <tr style="background:#F7F4F0;"><td style="padding:10px 16px;font-size:12px;font-weight:600;color:#6B6560;width:40%;text-transform:uppercase;">Ime i prezime</td><td style="padding:10px 16px;font-size:15px;font-weight:600;color:#1A1A1A;">${ime} ${prezime}</td></tr>
    <tr><td style="padding:10px 16px;font-size:12px;font-weight:600;color:#6B6560;text-transform:uppercase;border-top:1px solid #EDEBE7;">Adresa</td><td style="padding:10px 16px;font-size:15px;color:#1A1A1A;border-top:1px solid #EDEBE7;">${adresa}${grad ? ', ' + grad : ''}${ptt ? ' ' + ptt : ''}</td></tr>
    <tr style="background:#F7F4F0;"><td style="padding:10px 16px;font-size:12px;font-weight:600;color:#6B6560;text-transform:uppercase;border-top:1px solid #EDEBE7;">Telefon</td><td style="padding:10px 16px;font-size:15px;font-weight:600;color:#1A1A1A;border-top:1px solid #EDEBE7;"><a href="tel:${tel.replace(/\s/g,'')}" style="color:#FF5C2B;text-decoration:none;">${tel}</a></td></tr>
    ${napomena ? `<tr><td style="padding:10px 16px;font-size:12px;font-weight:600;color:#6B6560;text-transform:uppercase;border-top:1px solid #EDEBE7;">Napomena</td><td style="padding:10px 16px;font-size:14px;color:#3D3A36;border-top:1px solid #EDEBE7;font-style:italic;">${napomena}</td></tr>` : ''}
  </table>
</td></tr>
<tr><td style="padding:24px 40px 0;">
  <div style="font-size:11px;font-weight:700;letter-spacing:.14em;text-transform:uppercase;color:#FF5C2B;margin-bottom:12px;">Naručeni artikli</div>
  <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #EDEBE7;border-radius:10px;overflow:hidden;">
    <tr style="background:#F7F4F0;">
      <th style="padding:10px 16px;font-size:11px;font-weight:700;color:#6B6560;text-transform:uppercase;text-align:left;">Artikal</th>
      <th style="padding:10px 16px;font-size:11px;font-weight:700;color:#6B6560;text-transform:uppercase;text-align:center;">Kom.</th>
      <th style="padding:10px 16px;font-size:11px;font-weight:700;color:#6B6560;text-transform:uppercase;text-align:right;">Cijena</th>
    </tr>
    ${artikliRows}
  </table>
</td></tr>
<tr><td style="padding:16px 40px 0;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#FFF5F2;border:1px solid rgba(255,90,44,.2);border-radius:10px;">
    <tr><td style="padding:10px 20px;font-size:14px;color:#3D3A36;">Patike (${artikli.reduce((s,a)=>s+a.kolicina,0)} par(a))</td><td style="padding:10px 20px;font-size:14px;color:#3D3A36;text-align:right;">${fmtKM(subtotal)}</td></tr>
    <tr><td style="padding:8px 20px;font-size:14px;color:#3D3A36;border-top:1px solid rgba(255,90,44,.1);">Dostava</td><td style="padding:8px 20px;font-size:14px;color:#3D3A36;text-align:right;border-top:1px solid rgba(255,90,44,.1);">${fmtKM(dostava)}</td></tr>
    <tr><td style="padding:14px 20px;font-size:18px;font-weight:900;color:#1A1A1A;border-top:2px solid rgba(255,90,44,.2);">UKUPNO ZA NAPLATU</td><td style="padding:14px 20px;font-size:22px;font-weight:900;color:#FF5C2B;text-align:right;border-top:2px solid rgba(255,90,44,.2);">${fmtKM(total)}</td></tr>
  </table>
</td></tr>
<tr><td style="padding:16px 40px 0;">
  <div style="background:#F7F4F0;border-radius:10px;padding:14px 20px;font-size:13px;color:#6B6560;text-align:center;">Placanje pouzecem pri preuzimanju · Dostava 1–3 dana sirom BiH</div>
</td></tr>
<tr><td style="padding:28px 40px;text-align:center;border-top:1px solid #EDEBE7;margin-top:20px;">
  <div style="font-size:18px;font-weight:900;letter-spacing:.06em;text-transform:uppercase;color:#1A1A1A;">ADEX <span style="color:#FF5C2B;">PLUS</span></div>
  <div style="font-size:12px;color:#9E9790;margin-top:4px;">Zastitna radna obuca · EN ISO 20345 · S1P</div>
</td></tr>
</table>
</td></tr>
</table>
</body></html>`;

  try {
    const { data, error } = await resend.emails.send({
      from: 'ADEX PLUS <onboarding@resend.dev>',
      to:   'adnannarudzbe@gmail.com',
      subject: `Nova narudzba — ${ime} ${prezime} | ${fmtKM(total)}`,
      html
    });
    if (error) { console.error('Resend:', error); return res.status(500).json({ error: 'Greska pri slanju maila.' }); }
    console.log(`Mail poslan: ${ime} ${prezime} (${tel}) — ${fmtKM(total)}`);
    res.json({ success: true, id: data?.id });
  } catch (err) {
    console.error('Server error:', err);
    res.status(500).json({ error: 'Interna greska servera.' });
  }
};
