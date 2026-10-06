import 'package:email_validator/email_validator.dart';

/// Service untuk validasi email yang comprehensive
class EmailValidatorService {
  // Blacklist domain email dummy/temporary yang populer
  static const List<String> _blockedDomains = [
    // Temporary email services
    '10minutemail.com',
    'guerrillamail.com',
    'mailinator.com',
    'tempmail.com',
    'temp-mail.org',
    'throwaway.email',
    'getnada.com',
    'maildrop.cc',
    'trashmail.com',
    'fakeinbox.com',
    'yopmail.com',
    'mohmal.com',
    'emailondeck.com',
    'sharklasers.com',
    'grr.la',
    'guerrillamailblock.com',
    'pokemail.net',
    'spam4.me',
    'tmpeml.info',
    'mytemp.email',
    'temp-mail.io',
    'disposablemail.com',
    'dispostable.com',
    'throwawaymail.com',
    '20minutemail.com',
    'emailfake.com',
    'fakemail.net',
    'tempinbox.com',
    'mintemail.com',
    'spamgourmet.com',
    'mailnesia.com',
    'anonbox.net',
    'anonymousemail.me',
    'bugmenot.com',
    'deadaddress.com',
    'dodgit.com',
    'e4ward.com',
    'mailexpire.com',
    'maileater.com',
    'mailforspam.com',
    'mailmoat.com',
    'mailnull.com',
    'meltmail.com',
    'mintemail.com',
    'mt2014.com',
    'mytrashmail.com',
    'nepwk.com',
    'noclickemail.com',
    'nus.edu.sg',
    'objectmail.com',
    'oneoffemail.com',
    'pookmail.com',
    'put2.net',
    'rejectmail.com',
    'ruffrey.com',
    'safe-mail.net',
    'safetymail.info',
    'sandelf.de',
    'saynotospams.com',
    'selfdestructingmail.com',
    'SendSpamHere.com',
    'sharklasers.com',
    'shiftmail.com',
    'shortmail.net',
    'sibmail.com',
    'skeefmail.com',
    'slaskpost.se',
    'slopsbox.com',
    'smellfear.com',
    'snakemail.com',
    'sneakemail.com',
    'sofimail.com',
    'sogetthis.com',
    'soodonims.com',
    'spam.la',
    'spam.su',
    'spamavert.com',
    'spambob.com',
    'spambob.net',
    'spambob.org',
    'spambog.com',
    'spambog.de',
    'spambog.ru',
    'spambox.info',
    'spambox.irishspringrealty.com',
    'spambox.us',
    'spamcannon.com',
    'spamcannon.net',
    'spamcero.com',
    'spamcon.org',
    'spamcorptastic.com',
    'spamcowboy.com',
    'spamcowboy.net',
    'spamcowboy.org',
    'spamday.com',
    'spamex.com',
    'spamfree24.com',
    'spamfree24.de',
    'spamfree24.org',
    'spamgourmet.com',
    'spamgourmet.net',
    'spamgourmet.org',
    'spamherelots.com',
    'spamhereplease.com',
    'spamhole.com',
    'spamify.com',
    'spaminator.de',
    'spamkill.info',
    'spaml.com',
    'spaml.de',
    'spammotel.com',
    'spamobox.com',
    'spamoff.de',
    'spamslicer.com',
    'spamspot.com',
    'spamthis.co.uk',
    'spamthisplease.com',
    'spamtrail.com',
    'speed.1s.fr',
    'supergreatmail.com',
    'supermailer.jp',
    'suremail.info',
    'teewars.org',
    'teleworm.com',
    'teleworm.us',
    'tempalias.com',
    'tempe-mail.com',
    'tempemail.biz',
    'tempemail.com',
    'tempinbox.co.uk',
    'tempinbox.com',
    'tempmail.eu',
    'tempmaildemo.com',
    'tempmailer.com',
    'tempmailer.de',
    'tempomail.fr',
    'temporarily.de',
    'temporarioemail.com.br',
    'temporaryemail.net',
    'temporaryemail.us',
    'temporaryforwarding.com',
    'temporaryinbox.com',
    'temporarymailaddress.com',
    'thanksnospam.info',
    'thankyou2010.com',
    'thisisnotmyrealemail.com',
    'throwawayemailaddress.com',
    'tilien.com',
    'tittbit.in',
    'tmail.ws',
    'tmailinator.com',
    'tradermail.info',
    'trash-amil.com',
    'trash-mail.at',
    'trash-mail.com',
    'trash-mail.de',
    'trash2009.com',
    'trashdevil.com',
    'trashemail.de',
    'trashmail.at',
    'trashmail.com',
    'trashmail.de',
    'trashmail.me',
    'trashmail.net',
    'trashmail.org',
    'trashmail.ws',
    'trashmailer.com',
    'trashymail.com',
    'trashymail.net',
    'trialmail.de',
    'trillianpro.com',
    'twinmail.de',
    'tyldd.com',
    'uggsrock.com',
    'upliftnow.com',
    'uplipht.com',
    'venompen.com',
    'veryrealemail.com',
    'viditag.com',
    'viewcastmedia.com',
    'viewcastmedia.net',
    'viewcastmedia.org',
    'wegwerfadresse.de',
    'wegwerfemail.de',
    'wegwerfmail.de',
    'wegwerfmail.net',
    'wegwerfmail.org',
    'wetrainbayarea.com',
    'wetrainbayarea.org',
    'wh4f.org',
    'whyspam.me',
    'willselfdestruct.com',
    'winemaven.info',
    'wronghead.com',
    'wuzup.net',
    'wuzupmail.net',
    'www.e4ward.com',
    'www.gishpuppy.com',
    'www.mailinator.com',
    'wwwnew.eu',
    'xagloo.com',
    'xemaps.com',
    'xents.com',
    'xmaily.com',
    'xoxy.net',
    'yep.it',
    'yogamaven.com',
    'yopmail.com',
    'yopmail.fr',
    'yopmail.net',
    'yourdomain.com',
    'yuurok.com',
    'zehnminuten.de',
    'zehnminutenmail.de',
    'zippymail.info',
    'zoemail.net',
    'zoemail.org',
  ];

  /// Validasi email lengkap: format + domain tidak di-blacklist
  static String? validateEmail(String? email, {bool isRegistering = false}) {
    if (email == null || email.trim().isEmpty) {
      return 'Masukkan email Anda';
    }

    final trimmedEmail = email.trim().toLowerCase();

    // Validasi format dasar
    if (!EmailValidator.validate(trimmedEmail)) {
      return 'Format email tidak valid';
    }

    // Khusus saat register, cek blacklist domain
    if (isRegistering) {
      final domain = trimmedEmail.split('@').last.toLowerCase();
      
      if (_blockedDomains.contains(domain)) {
        return 'Email temporary/dummy tidak diperbolehkan.\nGunakan email asli yang bisa menerima kode OTP.';
      }

      // Cek domain suspicious (hanya 1-2 karakter sebelum TLD)
      final domainParts = domain.split('.');
      if (domainParts.length >= 2) {
        final mainDomain = domainParts[domainParts.length - 2];
        if (mainDomain.length <= 2) {
          return 'Domain email tidak valid.\nGunakan email dari provider terpercaya.';
        }
      }
    }

    return null;
  }

  /// Cek apakah email di-blacklist
  static bool isBlockedDomain(String email) {
    final domain = email.trim().toLowerCase().split('@').last;
    return _blockedDomains.contains(domain);
  }

  /// Get friendly error message untuk SMTP failure
  static String getSmtpErrorMessage(String email) {
    if (isBlockedDomain(email)) {
      return 'Email temporary/dummy tidak diperbolehkan. Gunakan email asli.';
    }
    
    return 'Email tidak dapat menerima kode OTP.\n'
           'Pastikan:\n'
           '• Email Anda valid dan aktif\n'
           '• Tidak menggunakan email temporary\n'
           '• Kotak masuk tidak penuh\n'
           'Coba gunakan email lain (Gmail, Outlook, Yahoo, dll).';
  }
}
