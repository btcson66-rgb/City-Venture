import copy,json,unittest
from empty_lot_report import ROOT,inspect

class EmptyLots(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.districts=[json.loads(p.read_text(encoding='utf-8')) for p in (ROOT/'game/data/districts').glob('*.json')]
    def test_all_shipped_districts_are_completed(self):
        for d in self.districts:self.assertEqual(inspect(d)['unhandled'],0,d['id'])
    def test_declaring_a_garden_does_not_hide_missing_art(self):
        d=copy.deepcopy(next(d for d in self.districts if d['id']=='airport'))
        d['props']=[]
        self.assertGreater(inspect(d)['unhandled'],0)
    def test_only_trees_do_not_complete_a_lot(self):
        d=copy.deepcopy(next(d for d in self.districts if d['id']=='residential'))
        d['props']=[{'sprite':'tree_round_b','x':x,'y':550} for x in range(0,2400,48)]
        self.assertGreater(inspect(d)['unhandled'],0)
if __name__=='__main__':unittest.main()
