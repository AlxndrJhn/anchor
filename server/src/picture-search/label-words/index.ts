import af from './af';
import am from './am';
import ar from './ar';
import az from './az';
import be from './be';
import bg from './bg';
import bn from './bn';
import bs from './bs';
import ca from './ca';
import cs from './cs';
import cy from './cy';
import da from './da';
import de from './de';
import el from './el';
import es from './es';
import et from './et';
import eu from './eu';
import fa from './fa';
import fi from './fi';
import fr from './fr';
import ga from './ga';
import gl from './gl';
import gu from './gu';
import he from './he';
import hi from './hi';
import hr from './hr';
import hu from './hu';
import hy from './hy';
import id from './id';
import is from './is';
import it from './it';
import ja from './ja';
import ka from './ka';
import kk from './kk';
import km from './km';
import kn from './kn';
import ko from './ko';
import lt from './lt';
import lv from './lv';
import mk from './mk';
import ml from './ml';
import mn from './mn';
import mr from './mr';
import ms from './ms';
import my from './my';
import nb from './nb';
import ne from './ne';
import nl from './nl';
import pa from './pa';
import pl from './pl';
import pt from './pt';
import ro from './ro';
import ru from './ru';
import si from './si';
import sk from './sk';
import sl from './sl';
import sq from './sq';
import sr from './sr';
import sv from './sv';
import sw from './sw';
import ta from './ta';
import te from './te';
import th from './th';
import tl from './tl';
import tr from './tr';
import uk from './uk';
import ur from './ur';
import uz from './uz';
import vi from './vi';
import yi from './yi';
import zhHans from './zh-Hans';
import zhHant from './zh-Hant';
import zu from './zu';
import type { LabelWords } from './words';

/** The tag words in every language besides English, by language code. */
export const LABEL_WORDS: Readonly<Record<string, LabelWords>> = {
  af,
  am,
  ar,
  az,
  be,
  bg,
  bn,
  bs,
  ca,
  cs,
  cy,
  da,
  de,
  el,
  es,
  et,
  eu,
  fa,
  fi,
  fr,
  ga,
  gl,
  gu,
  he,
  hi,
  hr,
  hu,
  hy,
  id,
  is,
  it,
  ja,
  ka,
  kk,
  km,
  kn,
  ko,
  lt,
  lv,
  mk,
  ml,
  mn,
  mr,
  ms,
  my,
  nb,
  ne,
  nl,
  pa,
  pl,
  pt,
  ro,
  ru,
  si,
  sk,
  sl,
  sq,
  sr,
  sv,
  sw,
  ta,
  te,
  th,
  tl,
  tr,
  uk,
  ur,
  uz,
  vi,
  yi,
  'zh-Hans': zhHans,
  'zh-Hant': zhHant,
  zu,
};
