use crate::oracle::pxe_db;
use protocol_types::{address::AztecAddress, traits::{Deserialize, Serialize}};

pub struct DBArray<T> {
    contract_address: AztecAddress,
    key: Field,
}

impl<T, let N: u32> DBArray<T>
where
    T: Serialize<N> + Deserialize<N>,
{
    pub unconstrained fn at(contract_address: AztecAddress, key: Field) -> Self {
        Self { contract_address, key }
    }

    pub unconstrained fn len(self) -> u32 {
        pxe_db::load(self.contract_address, self.key).unwrap_or(0) as u32
    }

    pub unconstrained fn push(self, value: T) {
        // Arrays are stored by storing their length at the key, and each element at each following key. For example, the
        // array [5, 7] at key 13 would have:
        //  - key: 13, value: 2
        //  - key: 14, value: 5
        //  - key: 15, value: 7

        let current_length = self.len();

        // `key + 1` is where the first element is located, so we get the first free slot by adding `current_length`
        pxe_db::store(self.contract_address, self.key_at(current_length), value);

        // Then we simply update the length
        let new_length = current_length + 1;
        pxe_db::store(self.contract_address, self.key, new_length);
    }

    pub unconstrained fn get(self, index: u32) -> T {
        assert(index < self.len(), "Attempted to read past the length of a DBArray");

        pxe_db::load(self.contract_address, self.key_at(index)).unwrap()
    }

    pub unconstrained fn remove(self, index: u32) {
        let current_length = self.len();
        assert(index < current_length, "Attempted to delete past the length of a DBArray");

        pxe_db::store(self.contract_address, self.key, current_length - 1);
    }

    unconstrained fn key_at(self, index: u32) -> Field {
        self.key + 1 + index as Field
    }
}

mod test {
    use crate::test::helpers::test_environment::TestEnvironment;
    use super::DBArray;
    use protocol_types::address::AztecAddress;

    global KEY: Field = 1234;

    unconstrained fn setup() -> AztecAddress {
        TestEnvironment::new().unkonstrained().this_address()
    }

    #[test]
    unconstrained fn empty_array() {
        let contract_address = setup();

        let array: DBArray<Field> = DBArray::at(contract_address, KEY);
        assert_eq(array.len(), 0);
    }

    #[test(should_fail_with = "Attempted to read past the length of a DBArray")]
    unconstrained fn empty_array_read() {
        let contract_address = setup();

        let array = DBArray::at(contract_address, KEY);
        let _: Field = array.get(0);
    }

    #[test]
    unconstrained fn array_push() {
        let contract_address = setup();

        let array = DBArray::at(contract_address, KEY);
        array.push(5);

        assert_eq(array.len(), 1);
        assert_eq(array.get(0), 5);
    }

    #[test(should_fail_with = "Attempted to read past the length of a DBArray")]
    unconstrained fn read_past_len() {
        let contract_address = setup();

        let array = DBArray::at(contract_address, KEY);
        array.push(5);

        let _ = array.get(1);
    }
}
