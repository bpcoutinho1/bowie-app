import 'package:bowie/features/pets/domain/pet.dart';

/// Suggested breeds, from docs/produto/pets.md. The PetCenso 2025 ranking
/// (Petlove) comes first, in order; then other common breeds in Brazil,
/// alphabetically. People can still type a breed that is not listed.
const noBreed = 'Sem raça definida (SRD)';

const dogBreeds = [
  noBreed,
  'Shih Tzu',
  'Yorkshire Terrier',
  'Spitz Alemão (Lulu da Pomerânia)',
  'Lhasa Apso',
  'Golden Retriever',
  'Pinscher',
  'Dachshund (Salsicha)',
  'Pug',
  'Maltês',
  'Beagle',
  'Border Collie',
  'Boxer',
  'Buldogue Francês',
  'Buldogue Inglês',
  'Chihuahua',
  'Cocker Spaniel',
  'Dálmata',
  'Doberman',
  'Fila Brasileiro',
  'Husky Siberiano',
  'Labrador Retriever',
  'Pastor Alemão',
  'Pastor Belga',
  'Pit Bull',
  'Poodle',
  'Rottweiler',
  'Schnauzer',
  'Shiba Inu',
  'Weimaraner',
];

const catBreeds = [
  noBreed,
  'Siamês',
  'Persa',
  'Maine Coon',
  'Angorá Turco',
  'Ragdoll',
  'Azul Russo',
  'Bengal',
  'British Shorthair',
  'Exótico de Pelo Curto',
  'Himalaio',
  'Sagrado da Birmânia',
  'Sphynx',
];

List<String> breedsFor(PetSpecies species) {
  return switch (species) {
    PetSpecies.dog => dogBreeds,
    PetSpecies.cat => catBreeds,
  };
}

/// Breeds whose name contains [query], ignoring case and accents. An empty
/// query returns the whole list in its suggested order.
List<String> searchBreeds(PetSpecies species, String query) {
  final all = breedsFor(species);
  final needle = _fold(query.trim());
  if (needle.isEmpty) return all;
  return [
    for (final breed in all)
      if (_fold(breed).contains(needle)) breed,
  ];
}

String _fold(String value) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = value.toLowerCase();
  final out = StringBuffer();
  for (final char in lower.split('')) {
    final i = from.indexOf(char);
    out.write(i == -1 ? char : to[i]);
  }
  return out.toString();
}
