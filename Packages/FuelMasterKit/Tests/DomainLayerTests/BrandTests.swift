import DomainLayer
import Testing

@Suite("Brands from signs")
struct BrandTests {
    @Test(arguments: [
        ("Repsol", Brand.repsol),
        ("REPSOL BUTANO", .repsol),
        ("E.Leclerc", .eleclerc),
        ("E.LECLERC ALCOBENDAS", .eleclerc),
        ("Bonàrea", .bonarea),
        ("BON AREA", .bonarea),
        ("BP", .bp),
        ("Q8", .q8),
        ("By Energy", .byEnergy),
        ("Gas Express", .gasexpress),
        ("ESCLAT", .esclatoil),
        ("Petroprix", .petroprix),
        ("Estación Avia Pozuelo", .avia),
        // The first chain in the sign wins.
        ("Shell Repsol", .shell),
    ])
    func recognisesSign(_ sign: String, _ brand: Brand) {
        #expect(Brand(sign: sign) == brand)
    }

    @Test(arguments: ["Autovía Sur", "Graham", "Paradisa", "Sin Rótulo", "", "Bpx"])
    func matchesWholeWordsOnly(_ sign: String) {
        #expect(Brand(sign: sign) == nil)
    }
}
