import copy,unittest
from map_adjacency_check import check,load

class MapChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.city,cls.districts=load()
    def broken(self,mutate):
        c,d=copy.deepcopy(self.city),copy.deepcopy(self.districts)
        mutate(c,d)
        self.assertTrue(check(c,d))
    def test_shipped_graph(self): self.assertEqual(check(self.city,self.districts),[])
    def test_wrong_direction(self): self.broken(lambda c,d:c['adjacency']['riverside'].__setitem__('startup_hub','W'))
    def test_extra_non_neighbor(self): self.broken(lambda c,d:d['airport']['exits'].append(copy.deepcopy(d['riverside']['exits'][0])))
    def test_missing_spawn(self): self.broken(lambda c,d:d['startup_hub']['spawns'].pop('from_riverside'))
    def test_wrong_spawn_side(self): self.broken(lambda c,d:d['startup_hub']['spawns'].__setitem__('from_riverside',[1000,400]))
    def test_blocked_corridor(self): self.broken(lambda c,d:d['university'].__setitem__('walk_corridors',[]))
    def test_exit_not_at_edge(self): self.broken(lambda c,d:d['riverside']['exits'][0]['rect'].__setitem__(0,100))

if __name__=='__main__':unittest.main()
