import XCTest
@testable import chezz

final class ProfileMappingTests: XCTestCase {

    // An older server omits `streak`; toUser() must default it to 0 (forward/backward compatible).
    func testProfileDecodesWithoutStreak() throws {
        let json = Data(#"{"id":"u1","username":"rico","rating":1300,"isFriend":true}"#.utf8)
        let user = try JSONDecoder().decode(ProfileDTO.self, from: json).toUser()
        XCTAssertEqual(user.streak, 0)
        XCTAssertEqual(user.rating, 1300)
    }

    func testProfileCarriesStreak() throws {
        let json = Data(#"{"id":"u1","username":"rico","rating":1300,"isFriend":true,"streak":7}"#.utf8)
        let user = try JSONDecoder().decode(ProfileDTO.self, from: json).toUser()
        XCTAssertEqual(user.streak, 7)
    }
}
